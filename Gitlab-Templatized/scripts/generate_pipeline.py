#!/usr/bin/env python3
"""
generate_pipeline.py
====================
Reads targets.json (produced by fetch_targets.py) and generates
dynamic-pipeline.yml -- a GitLab CI child pipeline with one Flyway migrate
job per target database.

This script has no database dependency.  Run fetch_targets.py first to
populate targets.json, then run this script to generate the pipeline.

Required
--------
targets.json must exist in the working directory (artifact from the
fetch-targets job).

Optional environment variables
-------------------------------
TARGETS_FILE         Input JSON filename      (default: targets.json)
OUTPUT_FILE          Output YAML filename     (default: dynamic-pipeline.yml)
FLYWAY_LOCATIONS     Flyway SQL file location (default: filesystem:./sql)

Runner tag variables
--------------------
RUNNER_TAG_LONDON    GitLab runner tag for London   (default: runner-london)
RUNNER_TAG_NEW_YORK  GitLab runner tag for New York (default: runner-new-york)
RUNNER_TAG_TOKYO     GitLab runner tag for Tokyo    (default: runner-tokyo)
"""

import json
import os
import sys
from typing import Any, Dict, List

import yaml


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

TARGETS_FILE     = os.environ.get("TARGETS_FILE",     "targets.json")
OUTPUT_FILE      = os.environ.get("OUTPUT_FILE",      "dynamic-pipeline.yml")
FLYWAY_LOCATIONS = os.environ.get("FLYWAY_LOCATIONS", "filesystem:./sql")

RUNNER_TAGS: Dict[str, str] = {
    "London":   os.environ.get("RUNNER_TAG_LONDON",   "runner-london"),
    "New York": os.environ.get("RUNNER_TAG_NEW_YORK", "runner-new-york"),
    "Tokyo":    os.environ.get("RUNNER_TAG_TOKYO",    "runner-tokyo"),
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def runner_tag_for(location: str) -> str:
    return RUNNER_TAGS.get(location, f"runner-{location.lower().replace(' ', '-')}")


def safe_job_name(value: str) -> str:
    return value.lower().replace(" ", "-").replace("_", "-").replace(".", "-")


# ---------------------------------------------------------------------------
# Pipeline generation
# ---------------------------------------------------------------------------

def make_job(target: Dict[str, Any]) -> Dict[str, Any]:
    """Build a single GitLab CI job dict for one database target."""
    env_name = (
        f"{safe_job_name(target['location'])}"
        f"/{safe_job_name(target['name'])}-{safe_job_name(target['db'])}"
    )
    return {
        "extends": ".flyway_migrate",
        "stage": "migrate",
        "tags": [runner_tag_for(target["location"])],
        "variables": {
            "FLYWAY_URL":      target["jdbc_url"],
            # Credentials are resolved at runtime from GitLab CI/CD variables
            "FLYWAY_USER":     "${TARGET_DATABASE_USER}",
            "FLYWAY_PASSWORD": "${TARGET_DATABASE_PASSWORD}",
        },
        "environment": {"name": env_name},
    }


def unique_job_name(base: str, seen: set) -> str:
    candidate = base
    n = 1
    while candidate in seen:
        candidate = f"{base}-{n}"
        n += 1
    return candidate


def build_pipeline(targets: List[Dict[str, Any]]) -> Dict[str, Any]:
    pipeline: Dict[str, Any] = {
        # Include shared Flyway templates so child jobs can extend them
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
            f":{safe_job_name(target['name'])}"
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
    if not os.path.exists(TARGETS_FILE):
        print(f"ERROR: {TARGETS_FILE} not found. Run fetch_targets.py first.", file=sys.stderr)
        sys.exit(1)

    with open(TARGETS_FILE) as f:
        targets = json.load(f)

    print(f"Read {len(targets)} targets from {TARGETS_FILE}")

    pipeline = build_pipeline(targets)

    with open(OUTPUT_FILE, "w") as f:
        yaml.dump(pipeline, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"Wrote {OUTPUT_FILE} ({len(targets)} deploy jobs)")
    for t in targets:
        print(f"  [{t['location']}] {t['name']}: {t['jdbc_url']}")


if __name__ == "__main__":
    main()
