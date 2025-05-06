#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./stop-cfg.sh testnet2.env
