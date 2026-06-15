#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf 'Nexo release validation failed: %s\n' "$1" >&2
  exit 1
}

release_tag="${NEXO_RELEASE_TAG:-${GITHUB_REF_NAME:-${1:-}}}"
chatwoot_version="$(tr -d '[:space:]' < VERSION_CW)"
nexo_version="$(tr -d '[:space:]' < VERSION_NEXO)"
expected_tag="v${nexo_version}"
source_commit="$(git rev-parse HEAD)"
image_name='ghcr.io/eliseoci/chatwoot-pipelines'

[[ -n "$release_tag" ]] || fail 'a release tag is required'
[[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-nexo\.[0-9]+$ ]] ||
  fail "tag '$release_tag' must match v<chatwoot>-nexo.<release>"
[[ "$release_tag" == "$expected_tag" ]] ||
  fail "tag '$release_tag' must equal VERSION_NEXO with a v prefix: $expected_tag"
[[ "$nexo_version" == "${chatwoot_version}-nexo."* ]] ||
  fail "VERSION_NEXO '$nexo_version' must use Chatwoot version '$chatwoot_version'"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'release_tag=%s\n' "$release_tag"
    printf 'chatwoot_version=%s\n' "$chatwoot_version"
    printf 'nexo_version=%s\n' "$nexo_version"
    printf 'source_commit=%s\n' "$source_commit"
    printf 'image_name=%s\n' "$image_name"
    printf 'image_ref=%s:%s\n' "$image_name" "$release_tag"
  } >> "$GITHUB_OUTPUT"
fi

printf 'Validated Nexo release %s at %s\n' "$release_tag" "$source_commit"
