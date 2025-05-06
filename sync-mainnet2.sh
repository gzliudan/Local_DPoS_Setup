#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./sync.sh mainnet2.env
