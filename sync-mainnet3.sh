#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./sync.sh mainnet3.env
