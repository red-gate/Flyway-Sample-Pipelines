#!/usr/bin/env python3
"""
fetch_targets.py
================
Queries the jdbc_table_store registry via usp_GetFlywayTargets and writes
the results to targets.json as a GitLab artifact.

targets.json is consumed by generate_pipeline.py in the next pipeline stage
to produce dynamic-pipeline.yml.  Separating these two steps means the
pipeline YAML generation has no database dependency.

Required environment variables
-------------------------------
REGISTRY_SERVER    SQL Server hostname for the registry database
REGISTRY_USER      Login on that server
REGISTRY_PASSWORD  Password  (mark as Protected + Masked in GitLab)

Optional environment variables
-------------------------------
REGISTRY_DATABASE  Registry DB name             (default: flyway_registry)
REGISTRY_PORT      SQL Server port              (default: 1433)
FILTER_LOCATION    'London' | 'New York' | 'Tokyo' | 'all'
                                                (default: all)
AVAILABLE_ONLY     '1' skip unavailable rows, '0' include all
                                                (default: 1)
INCLUDE_REPLICAS   '1' include replicas, '0' primaries only
                                                (default: 1)
SQL_SERVER_PORT    Port passed to sproc for JDBC URL construction
                                                (default: 1433)
OUTPUT_FILE        Output JSON filename         (default: targets.json)
"""

import json
import os
import sys

import pymssql

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REGISTRY = {
    "server":   os.environ.get("REGISTRY_SERVER",   ""),
    "port":     int(os.environ.get("REGISTRY_PORT", "1433")),
    "user":     os.environ.get("REGISTRY_USER",     ""),
    "password": os.environ.get("REGISTRY_PASSWORD", ""),
    "database": os.environ.get("REGISTRY_DATABASE", "flyway_registry"),
}

FILTER_LOCATION  = os.environ.get("FILTER_LOCATION",  "all")
INCLUDE_REPLICAS = int(os.environ.get("INCLUDE_REPLICAS", "1"))
AVAILABLE_ONLY   = int(os.environ.get("AVAILABLE_ONLY",  "1"))
SQL_SERVER_PORT  = int(os.environ.get("SQL_SERVER_PORT", "1433"))
OUTPUT_FILE      = os.environ.get("OUTPUT_FILE",      "targets.json")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def validate_config() -> None:
    missing = [k for k in ("server", "user", "password") if not REGISTRY[k]]
    if missing:
        env_names = [f"REGISTRY_{k.upper()}" for k in missing]
        print(f"ERROR: Missing required environment variables: {env_names}", file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------------------
# Registry query
# ---------------------------------------------------------------------------

def fetch_from_registry(location_filter, available_only, include_replicas, jdbc_port):
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
        cur.execute(
            "EXEC dbo.usp_GetFlywayTargets"
            " @location = %s,"
            " @available_only = %s,"
            " @jdbc_port = %s,"
            " @include_replicas = %s",
            (location_filter, available_only, jdbc_port, include_replicas),
        )
        return list(cur.fetchall())
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    validate_config()

    location_filter = FILTER_LOCATION if FILTER_LOCATION.lower() != "all" else None

    print(f"Registry : {REGISTRY['server']}:{REGISTRY['port']}/{REGISTRY['database']}")
    print(f"Location : {location_filter or 'all locations'}")
    print(f"Replicas : {'included' if INCLUDE_REPLICAS else 'excluded'}")
    print(f"Port     : {SQL_SERVER_PORT}")

    try:
        rows = fetch_from_registry(location_filter, AVAILABLE_ONLY, INCLUDE_REPLICAS, SQL_SERVER_PORT)
    except pymssql.OperationalError as exc:
        print(f"ERROR: Cannot connect to registry: {exc}", file=sys.stderr)
        sys.exit(1)
    except pymssql.DatabaseError as exc:
        print(f"ERROR: Query failed: {exc}", file=sys.stderr)
        sys.exit(1)

    # jdbc_url is built by the stored procedure -- no string construction needed here
    targets = [
        {
            "name":     row.get("id", row.get("db", "unknown")),
            "db":       row["db"],
            "dbserver": row["dbserver"],
            "location": row["location"],
            "jdbc_url": row["jdbc_url"],
        }
        for row in rows
    ]

    with open(OUTPUT_FILE, "w") as f:
        json.dump(targets, f, indent=2)

    print(f"\nWrote {len(targets)} targets → {OUTPUT_FILE}")
    for t in targets:
        print(f"  [{t['location']}] {t['name']}: {t['jdbc_url']}")


if __name__ == "__main__":
    main()
