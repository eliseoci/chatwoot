#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

expected_tag="v$(tr -d '[:space:]' < VERSION_NEXO)"

NEXO_RELEASE_TAG="$expected_tag" script/nexo/validate_release_tag.sh >/dev/null

if NEXO_RELEASE_TAG='v0.0.0-nexo.0' \
  script/nexo/validate_release_tag.sh >/dev/null 2>&1; then
  printf 'Expected a mismatched release tag to fail validation\n' >&2
  exit 1
fi

if NEXO_RELEASE_TAG='latest' \
  script/nexo/validate_release_tag.sh >/dev/null 2>&1; then
  printf 'Expected a floating release tag to fail validation\n' >&2
  exit 1
fi

printf 'Nexo release tag validation tests passed\n'
