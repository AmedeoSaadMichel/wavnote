#!/bin/sh
# File: test/native/run_pcm_tests.sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/wavnote-pcm-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
swiftc -module-cache-path "$test_dir/modules" \
  "$project_root/ios/Shared/RecordingPCMConverter.swift" \
  "$project_root/test/native/main.swift" -o "$test_dir/pcm-tests"
"$test_dir/pcm-tests"
