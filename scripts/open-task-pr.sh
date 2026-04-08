#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/github-workflow.sh
source "${script_dir}/lib/github-workflow.sh"

if [[ $# -ne 5 ]]; then
  echo "usage: $0 <issue-number> <base-branch> <head-branch> <title> <body-file>" >&2
  exit 1
fi

issue_number="$1"
base_branch="$2"
head_branch="$3"
title="$4"
body_file="$5"

[[ -f "${body_file}" ]] || ghwf_die "body file not found: ${body_file}"

issue_json="$(ghwf_issue_json "${issue_number}")"
issue_url="$(jq -r '.url' <<<"${issue_json}")"
issue_body="$(jq -r '.body' <<<"${issue_json}")"
milestone_title="$(jq -r '.milestone.title // empty' <<<"${issue_json}")"
issue_status="$(ghwf_issue_status "${issue_json}")"
login="$(ghwf_login)"

[[ -n "${milestone_title}" ]] || ghwf_die "issue #${issue_number} is missing a milestone"

if [[ "$(jq '.assignees | length' <<<"${issue_json}")" -lt 1 ]]; then
  gh issue edit "${issue_number}" --repo "$(ghwf_repo_full_name)" --add-assignee "${login}" >/dev/null
fi

issue_item_id="$(ghwf_ensure_project_item "${issue_url}")"
ghwf_set_project_status "${issue_item_id}" "In progress"

pr_body_file="$(mktemp)"
trap 'rm -f "${pr_body_file}"' EXIT

cp "${body_file}" "${pr_body_file}"
if ! grep -Eq "Closes #${issue_number}|Fixes #${issue_number}|Resolves #${issue_number}" "${pr_body_file}"; then
  printf '\n## Linked Issue\nCloses #%s\n' "${issue_number}" >>"${pr_body_file}"
fi

pr_url="$(
  gh pr create \
    --repo "$(ghwf_repo_full_name)" \
    --base "${base_branch}" \
    --head "${head_branch}" \
    --title "${title}" \
    --body-file "${pr_body_file}"
)"

pr_number="$(gh pr view "${pr_url}" --repo "$(ghwf_repo_full_name)" --json number -q .number)"

pr_edit_args=(
  gh pr edit "${pr_number}"
  --repo "$(ghwf_repo_full_name)"
  --add-assignee "${login}"
  --milestone "${milestone_title}"
)

while IFS= read -r label; do
  [[ -n "${label}" ]] || continue
  pr_edit_args+=(--add-label "${label}")
done < <(jq -r '.labels[].name' <<<"${issue_json}")

"${pr_edit_args[@]}" >/dev/null

pr_item_id="$(ghwf_ensure_project_item "${pr_url}")"
ghwf_set_project_status "${pr_item_id}" "${issue_status:-In progress}"

ghwf_update_issue_delivery "${issue_number}" "${head_branch}" "${pr_number}" "${pr_url}"

printf '%s\n' "${pr_url}"
