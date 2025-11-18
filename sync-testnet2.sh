#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./sync-by-cfg.sh testnet2
