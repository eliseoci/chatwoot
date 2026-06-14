#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf 'Nexo distribution guardrail failed: %s\n' "$1" >&2
  exit 1
}

chatwoot_version="$(tr -d '[:space:]' < VERSION_CW)"
nexo_version="$(tr -d '[:space:]' < VERSION_NEXO)"
escaped_chatwoot_version="${chatwoot_version//./\\.}"

if [[ ! "$nexo_version" =~ ^${escaped_chatwoot_version}-nexo\.[0-9]+$ ]]; then
  fail "VERSION_NEXO '$nexo_version' must match ${chatwoot_version}-nexo.<release>"
fi

if ! grep -q 'enterprise/' LICENSE; then
  fail 'root LICENSE no longer documents the Enterprise license boundary'
fi

base_ref="${NEXO_GUARDRAIL_BASE_REF:-}"

if [[ -z "$base_ref" && -n "${GITHUB_BASE_SHA:-}" ]]; then
  base_ref="$GITHUB_BASE_SHA"
fi

if [[ -z "$base_ref" && -n "${GITHUB_EVENT_BEFORE:-}" && ! "$GITHUB_EVENT_BEFORE" =~ ^0+$ ]]; then
  base_ref="$GITHUB_EVENT_BEFORE"
fi

changed_files=''
if [[ -n "$base_ref" ]] && git cat-file -e "${base_ref}^{commit}" 2>/dev/null; then
  changed_files="$(git diff --name-only "${base_ref}...HEAD")"
fi

working_tree_files="$(
  {
    git diff --name-only
    git diff --cached --name-only
    git ls-files --others --exclude-standard
  } | sort -u
)"

changed_files="$(
  {
    printf '%s\n' "$changed_files"
    printf '%s\n' "$working_tree_files"
  } | sed '/^$/d' | sort -u
)"

if [[ -n "$changed_files" ]] && printf '%s\n' "$changed_files" | grep -q '^enterprise/'; then
  fail 'Nexo changes must not modify files under enterprise/'
fi

pipeline_roots=(
  'app/models/pipeline'
  'app/models/pipelines/'
  'app/services/pipelines/'
  'app/jobs/pipelines/'
  'app/listeners/pipelines/'
  'app/policies/pipeline'
  'app/controllers/api/v1/accounts/pipeline'
  'app/views/api/v1/accounts/pipeline'
  'app/views/api/v1/models/_pipeline'
  'app/javascript/dashboard/api/pipeline'
  'app/javascript/dashboard/api/specs/pipeline'
  'app/javascript/dashboard/routes/dashboard/settings/pipelines/'
  'app/javascript/dashboard/routes/dashboard/pipelines/'
  'app/javascript/dashboard/store/modules/pipelines/'
  'config/locales/pipelines/'
  'db/migrate/'
  'spec/'
)

is_pipeline_domain_file() {
  local path="$1"
  local root

  case "$path" in
    *pipeline*|*pipelines*) ;;
    *) return 1 ;;
  esac

  for root in "${pipeline_roots[@]}"; do
    if [[ "$path" == "$root"* ]]; then
      return 0
    fi
  done

  return 1
}

while IFS= read -r path; do
  is_pipeline_domain_file "$path" || continue
  [[ -f "$path" ]] || continue

  if grep -nE '(enterprise/|Enterprise::|require[^[:alnum:]]+enterprise|from[^[:alnum:]]+.*enterprise)' "$path" >/dev/null; then
    fail "Pipeline domain file references Enterprise implementation: $path"
  fi

  basename_match="$(basename "$path")"
  while IFS= read -r enterprise_path; do
    if cmp -s "$path" "$enterprise_path"; then
      fail "Pipeline domain file is an exact copy of Enterprise code: $path"
    fi
  done < <(find enterprise -type f -name "$basename_match" 2>/dev/null)
done < <(git ls-files --cached --others --exclude-standard)

if [[ -n "$changed_files" ]]; then
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue

    case "$path" in
      *pipeline*|*pipelines*)
        case "$path" in
          docs/nexo/*|script/nexo/*|.github/workflows/nexo-*|VERSION_NEXO) ;;
          config/routes.rb|app/models/account.rb|app/models/contact.rb|app/models/conversation.rb) ;;
          app/javascript/dashboard/routes/*|app/javascript/dashboard/components/*|app/javascript/dashboard/i18n/*) ;;
          config/events.rb|config/locales/*) ;;
          *)
            if ! is_pipeline_domain_file "$path"; then
              fail "Pipeline change is outside a documented domain or integration path: $path"
            fi
            ;;
        esac
        ;;
    esac
  done <<< "$changed_files"
fi

printf 'Nexo distribution guardrails passed for %s\n' "$nexo_version"
