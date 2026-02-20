#!/bin/bash

# TODO - parameterize FW version, check for flyway on PATH before install

FLYWAY_VERSION="10.17.1"

echo "Downloading and unzipping Flyway ${FLYWAY_VERSION}..."
curl -sS https://download.red-gate.com/maven/release/com/redgate/flyway/flyway-commandline/10.17.1/flyway-commandline-10.17.1-linux-x64.tar.gz | tar xz >/dev/null    
export PATH="$(System.DefaultWorkingDirectory)/flyway-${FLYWAY_VERSION}:$PATH"  
flyway --version