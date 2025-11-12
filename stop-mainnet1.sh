#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./stop-cfg.sh mainnet1
