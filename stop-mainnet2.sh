#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./stop-cfg.sh mainnet2.env
