#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/github-workflow.sh
source "${script_dir}/lib/github-workflow.sh"

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: $0 <head-branch> <title> <body-file> [milestone-title]" >&2
  exit 1
fi

head_branch="$1"
title="$2"
body_file="$3"
milestone_title="${4:-}"

[[ -f "${body_file}" ]] || ghwf_die "body file not found: ${body_file}"
[[ "${head_branch}" == milestone/* ]] || ghwf_die "milestone PRs must use a milestone/* head branch"

login="$(ghwf_login)"
if [[ -z "${milestone_title}" ]]; then
  milestone_title="$(ghwf_detect_milestone_title_from_branch "${head_branch}")"
fi

pr_url="$(
  gh pr create \
    --repo "$(ghwf_repo_full_name)" \
    --base main \
    --head "${head_branch}" \
    --title "${title}" \
    --body-file "${body_file}"
)"

pr_number="$(gh pr view "${pr_url}" --repo "$(ghwf_repo_full_name)" --json number -q .number)"

ghwf_ensure_label "milestone" "5319e7" "Milestone PR into main"

pr_edit_args=(
  gh pr edit "${pr_number}"
  --repo "$(ghwf_repo_full_name)"
  --add-assignee "${login}"
  --add-label "milestone"
)

if [[ -n "${milestone_title}" ]]; then
  pr_edit_args+=(--milestone "${milestone_title}")
fi

"${pr_edit_args[@]}" >/dev/null

pr_item_id="$(ghwf_ensure_project_item "${pr_url}")"
ghwf_set_project_status "${pr_item_id}" "In progress"

gh pr comment "${pr_number}" --repo "$(ghwf_repo_full_name)" --body "@codex review" >/dev/null

printf '%s\n' "${pr_url}"
