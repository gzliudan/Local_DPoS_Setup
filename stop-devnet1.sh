#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./stop-cfg.sh devnet1
