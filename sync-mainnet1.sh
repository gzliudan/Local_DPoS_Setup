#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./sync.sh mainnet1.env
