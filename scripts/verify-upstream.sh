#!/usr/bin/env bash
# oc-port-agent verification: build the .ipa against the upstream commit being synced
# (read from the agent packet), or upstream dev when run by hand. Needs Xcode 26+.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
packet="$repo/.oc-port/context/packet.json"
revision=dev
if [[ -f "$packet" ]]; then
  revision=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["plan"]["to"])' "$packet")
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
"$repo/scripts/fetch-upstream.sh" "$work/upstream" "$revision"

# The patch scripts are agent-edited, so run them without the job's tokens.
env -i PATH="$PATH" HOME="$HOME" USER="${USER:-$(id -un)}" LOGNAME="${LOGNAME:-$(id -un)}" \
  TMPDIR="${TMPDIR:-/tmp}" LANG="${LANG:-en_US.UTF-8}" \
  ${DEVELOPER_DIR:+DEVELOPER_DIR="$DEVELOPER_DIR"} RUNNER_TEMP="$work" \
  "$repo/scripts/build-ipa.sh" "$work/upstream" "$work/Hex.ipa" 0.0.0 0
