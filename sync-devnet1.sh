#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

./sync.sh devnet1.env
