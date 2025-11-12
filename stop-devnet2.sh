#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./stop-by-cfg.sh devnet2
