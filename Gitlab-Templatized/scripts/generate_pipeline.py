#!/usr/bin/env python3
"""
generate_pipeline.py
====================
Queries the jdbc_table_store registry via usp_GetFlywayTargets and
produces a GitLab CI child pipeline YAML file with one Flyway migrate job per
target database.  The generated file is consumed by a parent pipeline trigger.

Required environment variables
-------------------------------
REGISTRY_SERVER      SQL Server hostname (or host:port) for the registry DB
REGISTRY_USER        Registry database login
REGISTRY_PASSWORD    Registry database password

Optional environment variables
-------------------------------
REGISTRY_DATABASE    Registry DB name             (default: flyway_registry)
REGISTRY_PORT        SQL Server port              (default: 1433)
FILTER_LOCATION      'London', 'New York', 'Tokyo', or 'all'
                                                  (default: all)
INCLUDE_REPLICAS     '1' to include replicated entries, '0' primaries only
                                                  (default: 1)
SQL_SERVER_PORT      Target SQL Server port for JDBC strings
                                                  (default: 1433)
FLYWAY_LOCATIONS     Flyway SQL file location     (default: filesystem:./sql)
OUTPUT_FILE          Output YAML filename         (default: generated-child-pipeline.yml)

Runner tag variables (configurable per GitLab project)
-------------------------------------------------------
RUNNER_TAG_LONDON    GitLab runner tag for London  (default: runner-london)
RUNNER_TAG_NEW_YORK  GitLab runner tag for NY      (default: runner-new-york)
RUNNER_TAG_TOKYO     GitLab runner tag for Tokyo   (default: runner-tokyo)
"""

import os
import sys
from typing import Any, Dict, List, Optional

import pymssql
import yaml


# ---------------------------------------------------------------------------
# Configuration – read once from environment
# ---------------------------------------------------------------------------

REGISTRY = {
    "server":   os.environ.get("REGISTRY_SERVER", ""),
    "port":     int(os.environ.get("REGISTRY_PORT", "1433")),
    "user":     os.environ.get("REGISTRY_USER", ""),
    "password": os.environ.get("REGISTRY_PASSWORD", ""),
    "database": os.environ.get("REGISTRY_DATABASE", "flyway_registry"),
}

RUNNER_TAGS: Dict[str, str] = {
    "London":   os.environ.get("RUNNER_TAG_LONDON",   "runner-london"),
    "New York": os.environ.get("RUNNER_TAG_NEW_YORK", "runner-new-york"),
    "Tokyo":    os.environ.get("RUNNER_TAG_TOKYO",    "runner-tokyo"),
}

FILTER_LOCATION  = os.environ.get("FILTER_LOCATION",  "all")
INCLUDE_REPLICAS = os.environ.get("INCLUDE_REPLICAS", "1")
SQL_SERVER_PORT  = os.environ.get("SQL_SERVER_PORT",  "1433")
FLYWAY_LOCATIONS = os.environ.get("FLYWAY_LOCATIONS", "filesystem:./sql")
OUTPUT_FILE      = os.environ.get("OUTPUT_FILE", "generated-child-pipeline.yml")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def validate_config() -> None:
    missing = [k for k in ("server", "user", "password") if not REGISTRY[k]]
    if missing:
        env_names = [f"REGISTRY_{k.upper()}" for k in missing]
        print(f"ERROR: Missing required environment variables: {env_names}", file=sys.stderr)
        sys.exit(1)


def runner_tag_for(location: str) -> str:
    """Return the GitLab runner tag for a given location string."""
    return RUNNER_TAGS.get(location, f"runner-{location.lower().replace(' ', '-')}")


def safe_job_name(value: str) -> str:
    """Normalise a string to a safe GitLab job name segment."""
    return value.lower().replace(" ", "-").replace("_", "-").replace(".", "-")


def build_jdbc(dbserver: str, db: str, port: str = "1433") -> str:
    return (
        f"jdbc:sqlserver://{dbserver}:{port}"
        f";databaseName={db}"
        f";encrypt=false;trustServerCertificate=true"
    )


# ---------------------------------------------------------------------------
# Registry query
# ---------------------------------------------------------------------------

def fetch_targets(location_filter: Optional[str], include_replicas: int) -> List[Dict[str, Any]]:
    """
    Call usp_GetFlywayTargets on the registry database and return results
    as a list of dicts.
    """
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
        if location_filter:
            cur.execute(
                "EXEC dbo.usp_GetFlywayTargets"
                " @location = %s,"
                " @include_replicas = %s",
                (location_filter, include_replicas),
            )
        else:
            cur.execute(
                "EXEC dbo.usp_GetFlywayTargets"
                " @include_replicas = %s",
                (include_replicas,),
            )
        return list(cur.fetchall())
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Pipeline generation
# ---------------------------------------------------------------------------

def make_job(target: Dict[str, Any]) -> Dict[str, Any]:
    """Build a single GitLab CI job dict for one database target."""
    jdbc = build_jdbc(target["dbserver"], target["db"], SQL_SERVER_PORT)
    env_name = (
        f"{safe_job_name(target['location'])}/"
        f"{safe_job_name(target['id'])}-{safe_job_name(target['db'])}"
    )
    return {
        "extends": ".flyway_migrate",
        "stage": "migrate",
        "tags": [runner_tag_for(target["location"])],
        "variables": {
            "FLYWAY_URL":      jdbc,
            # Credentials come from GitLab CI/CD variables – never hardcoded
            "FLYWAY_USER":     "${TARGET_DATABASE_USER}",
            "FLYWAY_PASSWORD": "${TARGET_DATABASE_PASSWORD}",
        },
        "environment": {"name": env_name},
    }


def unique_job_name(base: str, seen: set) -> str:
    """Return base if unique, otherwise append an incrementing suffix."""
    candidate = base
    n = 1
    while candidate in seen:
        candidate = f"{base}-{n}"
        n += 1
    return candidate


def build_pipeline(targets: List[Dict[str, Any]]) -> Dict[str, Any]:
    pipeline: Dict[str, Any] = {
        # Include the shared Flyway templates so child jobs can extend them
        "include": [{"local": "/.gitlab/ci/flyway.yml"}],
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

    seen_names: set = set()
    for target in targets:
        base = (
            f"migrate"
            f":{safe_job_name(target['location'])}"
            f":{safe_job_name(target['id'])}"
            f":{safe_job_name(target['db'])}"
        )
        job_name = unique_job_name(base, seen_names)
        seen_names.add(job_name)
        pipeline[job_name] = make_job(target)

    return pipeline


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    validate_config()

    location_filter = FILTER_LOCATION if FILTER_LOCATION.lower() != "all" else None
    include_replicas = int(INCLUDE_REPLICAS)

    print(f"Registry : {REGISTRY['server']}:{REGISTRY['port']}/{REGISTRY['database']}")
    print(f"Location : {location_filter or 'all locations'}")
    print(f"Replicas : {'included' if include_replicas else 'excluded'}")
    print(f"Output   : {OUTPUT_FILE}")
    print()

    try:
        targets = fetch_targets(location_filter, include_replicas)
    except pymssql.OperationalError as exc:
        print(f"ERROR: Cannot connect to registry database: {exc}", file=sys.stderr)
        sys.exit(1)
    except pymssql.DatabaseError as exc:
        print(f"ERROR: Query failed: {exc}", file=sys.stderr)
        sys.exit(1)

    print(f"Targets found: {len(targets)}")
    for t in targets:
        print(f"  [{t['location']:10s}]  {t['dbserver']}/{t['db']}")

    pipeline = build_pipeline(targets)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as fh:
        yaml.dump(pipeline, fh, default_flow_style=False, sort_keys=False, allow_unicode=True)

    job_count = sum(1 for k in pipeline if not k.startswith(("include", "stages", "variables")))
    print(f"\nGenerated {job_count} job(s) → {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
