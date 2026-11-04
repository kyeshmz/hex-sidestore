#!/usr/bin/env bash
# Check out the parts of upstream Hex that the iOS build reads, with full commit
# history (blobless) so commit counts and logs work.
# Usage: scripts/fetch-upstream.sh <destination> [<commit-or-branch>]
set -euo pipefail

destination=$1
revision=${2:-dev}

git clone -q --filter=blob:none --no-checkout https://github.com/anomalyco/hex.git "$destination"
git -C "$destination" sparse-checkout set ios app/AppIcon.icon tests/fixtures/vocabulary/audio
git -C "$destination" checkout -q "$revision"
