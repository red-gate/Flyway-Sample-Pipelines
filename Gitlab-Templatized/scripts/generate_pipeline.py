#!/usr/bin/env python3
"""
generate_pipeline.py
====================
Single script that queries the jdbc_table_store registry via a stored
procedure, builds JDBC connection strings, and generates a GitLab CI
child pipeline YAML with one Flyway migrate job per target database.

The stored procedure (dbo.usp_GetFlywayTargets) returns rows with at
minimum these columns:
    dbserver   - SQL Server hostname
    db         - database name on that server
    location   - region/site name (e.g. London, New York, Tokyo)
    id         - short logical identifier (e.g. CustHist1, CodeBase)
    name       - human-readable name
    available  - 1 = available for deployment
    replicated - 1 = replica (excluded by default)

The script:
  1. Calls the sproc and receives all rows
  2. Filters by location and availability
  3. Constructs JDBC URLs from dbserver + db
  4. Writes dynamic-pipeline.yml with one .flyway_migrate job per target

Required environment variables
-------------------------------
REGISTRY_SERVER    SQL Server hostname for the registry database
REGISTRY_USER      Login on that server
REGISTRY_PASSWORD  Password (mark as Protected + Masked in GitLab)

Optional environment variables
-------------------------------
REGISTRY_DATABASE    Registry DB name              (default: flyway_registry)
REGISTRY_PORT        SQL Server port               (default: 1433)
JDBC_PORT            Port for target JDBC URLs     (default: 1433)
FILTER_LOCATION      Region to deploy to           (default: all)
INCLUDE_REPLICAS     Include replicated DBs         (default: false)
FLYWAY_LOCATIONS     Migration file path           (default: filesystem:./migrations)
TEMPLATE_PROJECT     Templates repo path for child pipeline include
TEMPLATE_REF         Templates repo ref for child pipeline include
OUTPUT_FILE          Output YAML filename          (default: dynamic-pipeline.yml)
RUNNER_TAG_MAP       JSON map of location->runner tag overrides
RUNNER_TAG_LONDON    Runner tag for London         (default: runner-london)
RUNNER_TAG_NEW_YORK  Runner tag for New York       (default: runner-new-york)
RUNNER_TAG_TOKYO     Runner tag for Tokyo          (default: runner-tokyo)
"""

import json
import os
import sys

import pymssql
import yaml


# ---------------------------------------------------------------------------
# Configuration from environment
# ---------------------------------------------------------------------------

REGISTRY = {
    "server":   os.environ.get("REGISTRY_SERVER",   ""),
    "port":     int(os.environ.get("REGISTRY_PORT", "1433")),
    "user":     os.environ.get("REGISTRY_USER",     ""),
    "password": os.environ.get("REGISTRY_PASSWORD", ""),
    "database": os.environ.get("REGISTRY_DATABASE", "flyway_registry"),
}

JDBC_PORT        = os.environ.get("JDBC_PORT", "1433")
FILTER_LOCATION  = os.environ.get("FILTER_LOCATION", "all")
INCLUDE_REPLICAS = os.environ.get("INCLUDE_REPLICAS", "false").lower() in ("true", "1", "yes")
FLYWAY_LOCATIONS = os.environ.get("FLYWAY_LOCATIONS", "filesystem:./migrations")
OUTPUT_FILE      = os.environ.get("OUTPUT_FILE", "dynamic-pipeline.yml")

# For the child pipeline's include directive
TEMPLATE_PROJECT = os.environ.get("TEMPLATE_PROJECT", "")
TEMPLATE_REF     = os.environ.get("TEMPLATE_REF", "main")

# Runner tags — JSON map takes priority, then individual env vars, then defaults
_runner_tag_map_raw = os.environ.get("RUNNER_TAG_MAP", "")
if _runner_tag_map_raw:
    RUNNER_TAGS = json.loads(_runner_tag_map_raw)
else:
    RUNNER_TAGS = {
        "London":   os.environ.get("RUNNER_TAG_LONDON",   "runner-london"),
        "New York": os.environ.get("RUNNER_TAG_NEW_YORK", "runner-new-york"),
        "Tokyo":    os.environ.get("RUNNER_TAG_TOKYO",    "runner-tokyo"),
    }


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def validate_config():
    missing = [k for k in ("server", "user", "password") if not REGISTRY[k]]
    if missing:
        env_names = [f"REGISTRY_{k.upper()}" for k in missing]
        print(f"ERROR: Missing required environment variables: {env_names}", file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------------------
# Database query
# ---------------------------------------------------------------------------

def fetch_targets():
    """Call the stored procedure and return all rows as dicts."""
    conn = pymssql.connect(
        server=REGISTRY["server"],
        port=REGISTRY["port"],
        user=REGISTRY["user"],
        password=REGISTRY["password"],
        database=REGISTRY["database"],
        as_dict=True,
        login_timeout=15,
        timeout=30,
    )
    try:
        cur = conn.cursor()
        cur.execute("EXEC dbo.usp_GetFlywayTargets")
        return list(cur.fetchall())
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Filtering and JDBC construction
# ---------------------------------------------------------------------------

def build_jdbc_url(dbserver, db, port):
    """Construct a SQL Server JDBC connection string."""
    return (
        f"jdbc:sqlserver://{dbserver}:{port};"
        f"databaseName={db};"
        f"encrypt=false;"
        f"trustServerCertificate=true"
    )


def filter_and_build_targets(rows):
    """Filter rows by location/availability/replication, then build JDBC URLs."""
    location_filter = None if FILTER_LOCATION.lower() == "all" else FILTER_LOCATION

    # Filter to available databases only
    filtered = [r for r in rows if r.get("available", 0) == 1]
    print(f"  Available databases: {len(filtered)}")

    # Exclude replicas unless requested
    if not INCLUDE_REPLICAS:
        filtered = [r for r in filtered if not r.get("replicated", 0)]
        print(f"  After excluding replicas: {len(filtered)}")

    # Filter by location
    if location_filter:
        filtered = [r for r in filtered if r.get("location", "") == location_filter]
        print(f"  After location filter ({location_filter!r}): {len(filtered)}")

    # Build target list with JDBC URLs
    targets = []
    for row in filtered:
        targets.append({
            "name":     row.get("id", row.get("db", "unknown")),
            "db":       row["db"],
            "dbserver": row["dbserver"],
            "location": row["location"],
            "jdbc_url": build_jdbc_url(row["dbserver"], row["db"], JDBC_PORT),
        })

    return targets


# ---------------------------------------------------------------------------
# Pipeline YAML generation
# ---------------------------------------------------------------------------

def safe_job_name(value):
    return value.lower().replace(" ", "-").replace("_", "-").replace(".", "-")


def runner_tag_for(location):
    return RUNNER_TAGS.get(location, f"runner-{location.lower().replace(' ', '-')}")


def unique_job_name(base, seen):
    candidate = base
    n = 1
    while candidate in seen:
        candidate = f"{base}-{n}"
        n += 1
    return candidate


def build_pipeline(targets):
    """Generate a GitLab CI pipeline dict from the target list."""

    # Determine how the child pipeline includes flyway.yml
    if TEMPLATE_PROJECT:
        include_entry = {
            "project": TEMPLATE_PROJECT,
            "ref": TEMPLATE_REF,
            "file": "/.gitlab/ci/flyway.yml",
        }
    else:
        include_entry = {"local": "/.gitlab/ci/flyway.yml"}

    pipeline = {
        "include": [include_entry],
        "stages": ["migrate"],
        "variables": {
            "FLYWAY_LOCATIONS": FLYWAY_LOCATIONS,
        },
    }

    if not targets:
        pipeline["no-targets-found"] = {
            "stage": "migrate",
            "script": [
                'echo "WARNING: No deployment targets found."',
                'echo "Check FILTER_LOCATION and registry availability."',
            ],
        }
        return pipeline

    seen_names = set()
    for target in targets:
        base = (
            f"migrate"
            f":{safe_job_name(target['location'])}"
            f":{safe_job_name(target['name'])}"
            f":{safe_job_name(target['db'])}"
        )
        job_name = unique_job_name(base, seen_names)
        seen_names.add(job_name)

        env_name = (
            f"{safe_job_name(target['location'])}"
            f"/{safe_job_name(target['name'])}-{safe_job_name(target['db'])}"
        )

        pipeline[job_name] = {
            "extends": ".flyway_migrate",
            "stage": "migrate",
            "tags": [runner_tag_for(target["location"])],
            "variables": {
                "FLYWAY_URL":      target["jdbc_url"],
                "FLYWAY_USER":     "${TARGET_DATABASE_USER}",
                "FLYWAY_PASSWORD": "${TARGET_DATABASE_PASSWORD}",
            },
            "environment": {"name": env_name},
        }

    return pipeline


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    validate_config()

    print("=" * 60)
    print("Flyway Pipeline Generator")
    print("=" * 60)
    print(f"Registry : {REGISTRY['server']}:{REGISTRY['port']}/{REGISTRY['database']}")
    print(f"Location : {FILTER_LOCATION}")
    print(f"Replicas : {'included' if INCLUDE_REPLICAS else 'excluded'}")
    print(f"JDBC port: {JDBC_PORT}")
    print()

    # 1. Fetch all rows from the registry sproc
    try:
        rows = fetch_targets()
    except pymssql.OperationalError as exc:
        print(f"ERROR: Cannot connect to registry: {exc}", file=sys.stderr)
        sys.exit(1)
    except pymssql.DatabaseError as exc:
        print(f"ERROR: Query failed: {exc}", file=sys.stderr)
        sys.exit(1)

    print(f"Fetched {len(rows)} total rows from registry")

    # 2. Filter and build JDBC URLs
    targets = filter_and_build_targets(rows)

    print(f"\nTarget databases ({len(targets)}):")
    for t in targets:
        print(f"  [{t['location']}] {t['name']}: {t['jdbc_url']}")

    # 3. Generate the child pipeline YAML
    pipeline = build_pipeline(targets)

    with open(OUTPUT_FILE, "w") as f:
        yaml.dump(pipeline, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"\nWrote {OUTPUT_FILE} with {len(targets)} deploy jobs")


if __name__ == "__main__":
    main()
