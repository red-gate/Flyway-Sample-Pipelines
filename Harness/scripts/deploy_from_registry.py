#!/usr/bin/env python3
"""
deploy_from_registry.py
=======================
Harness Open Source equivalent of the GitLab dynamic pipeline generator.

Since Harness OS does not support dynamic child pipelines, this script
queries the registry, builds JDBC URLs, and runs `flyway migrate` for
each target database directly.

Required environment variables:
    REGISTRY_SERVER, REGISTRY_USER, REGISTRY_PASSWORD

Optional environment variables:
    REGISTRY_DATABASE    (default: flyway_registry)
    REGISTRY_PORT        (default: 1433)
    JDBC_PORT            (default: 1433)
    FILTER_LOCATION      (default: all)
    INCLUDE_REPLICAS     (default: false)
    TARGET_DATABASE_USER
    TARGET_DATABASE_PASSWORD
    FLYWAY_EMAIL
    FLYWAY_TOKEN
"""

import os
import subprocess
import sys

import pymssql


# ---------------------------------------------------------------------------
# Load .env file if present (local development)
# ---------------------------------------------------------------------------

def load_dotenv(path=None):
    if path is None:
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, ".env")
    path = os.path.normpath(path)
    if not os.path.isfile(path):
        return
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip()
            if key not in os.environ:
                os.environ[key] = value


load_dotenv()


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REGISTRY = {
    "server":   os.environ.get("REGISTRY_SERVER", ""),
    "port":     int(os.environ.get("REGISTRY_PORT", "1433")),
    "user":     os.environ.get("REGISTRY_USER", ""),
    "password": os.environ.get("REGISTRY_PASSWORD", ""),
    "database": os.environ.get("REGISTRY_DATABASE", "flyway_registry"),
}

JDBC_PORT        = os.environ.get("JDBC_PORT", "1433")
FILTER_LOCATION  = os.environ.get("FILTER_LOCATION", "all")
INCLUDE_REPLICAS = os.environ.get("INCLUDE_REPLICAS", "false").lower() in ("true", "1", "yes")

TARGET_USER     = os.environ.get("TARGET_DATABASE_USER", "")
TARGET_PASSWORD = os.environ.get("TARGET_DATABASE_PASSWORD", "")
FLYWAY_EMAIL    = os.environ.get("FLYWAY_EMAIL", "")
FLYWAY_TOKEN    = os.environ.get("FLYWAY_TOKEN", "")


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
    return (
        f"jdbc:sqlserver://{dbserver}:{port};"
        f"databaseName={db};"
        f"encrypt=false;"
        f"trustServerCertificate=true"
    )


def filter_and_build_targets(rows):
    location_filter = None if FILTER_LOCATION.lower() == "all" else FILTER_LOCATION

    filtered = [r for r in rows if r.get("available", 0) == 1]
    print(f"  Available databases: {len(filtered)}")

    if not INCLUDE_REPLICAS:
        filtered = [r for r in filtered if not r.get("replicated", 0)]
        print(f"  After excluding replicas: {len(filtered)}")

    if location_filter:
        filtered = [r for r in filtered if r.get("location", "") == location_filter]
        print(f"  After location filter ({location_filter!r}): {len(filtered)}")

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
# Run Flyway for a single target
# ---------------------------------------------------------------------------

def run_flyway(target):
    """Run flyway migrate for a single target database."""
    env = os.environ.copy()
    env["FLYWAY_URL"] = target["jdbc_url"]
    env["FLYWAY_USER"] = TARGET_USER
    env["FLYWAY_PASSWORD"] = TARGET_PASSWORD
    env["FLYWAY_EMAIL"] = FLYWAY_EMAIL
    env["FLYWAY_TOKEN"] = FLYWAY_TOKEN
    env["FLYWAY_BASELINE_ON_MIGRATE"] = "true"

    print(f"\n{'=' * 60}")
    print(f"  [{target['location']}] {target['name']}: {target['db']}")
    print(f"  JDBC: {target['jdbc_url']}")
    print(f"{'=' * 60}")

    # Info
    print("\n--- Pre-Migration Info ---")
    result = subprocess.run(["flyway", "info"], env=env)
    if result.returncode != 0:
        print(f"  WARNING: flyway info returned {result.returncode}")

    # Migrate
    print("\n--- Migrate ---")
    result = subprocess.run(["flyway", "migrate"], env=env)
    if result.returncode != 0:
        print(f"  ERROR: flyway migrate failed for {target['db']}")
        return False

    # Snapshot
    print("\n--- Post-Migration Snapshot ---")
    subprocess.run(["flyway", "snapshot", "-filename=snapshothistory:current"], env=env)

    # Final info
    print("\n--- Post-Migration Info ---")
    subprocess.run(["flyway", "info"], env=env)

    return True


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    validate_config()

    print("=" * 60)
    print("Flyway Registry-Driven Deployment")
    print("=" * 60)
    print(f"Registry : {REGISTRY['server']}:{REGISTRY['port']}/{REGISTRY['database']}")
    print(f"Location : {FILTER_LOCATION}")
    print(f"Replicas : {'included' if INCLUDE_REPLICAS else 'excluded'}")
    print(f"JDBC port: {JDBC_PORT}")
    print()

    # 1. Fetch targets
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

    if not targets:
        print("\nWARNING: No deployment targets found.")
        print("Check FILTER_LOCATION and registry availability.")
        return

    # 3. Run Flyway for each target
    # NOTE: In Harness OS, we cannot spawn parallel child pipelines,
    # so targets are processed sequentially. For parallel execution,
    # create separate pipelines per region.
    successes = 0
    failures = 0
    for target in targets:
        if run_flyway(target):
            successes += 1
        else:
            failures += 1

    # 4. Summary
    print(f"\n{'=' * 60}")
    print(f"  Deployment Summary")
    print(f"{'=' * 60}")
    print(f"  Total targets: {len(targets)}")
    print(f"  Succeeded:     {successes}")
    print(f"  Failed:        {failures}")
    print(f"{'=' * 60}")

    if failures > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
