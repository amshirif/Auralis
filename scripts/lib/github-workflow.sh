#!/usr/bin/env bash

set -euo pipefail

ghwf_die() {
  echo "$*" >&2
  exit 1
}

ghwf_repo_full_name() {
  local remote
  remote="$(git remote get-url origin)"

  if [[ "${remote}" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return
  fi

  ghwf_die "unable to infer GitHub repo from origin remote: ${remote}"
}

ghwf_repo_owner() {
  ghwf_repo_full_name | cut -d/ -f1
}

ghwf_repo_name() {
  ghwf_repo_full_name | cut -d/ -f2
}

ghwf_login() {
  if [[ -z "${GHWF_LOGIN:-}" ]]; then
    GHWF_LOGIN="$(gh api user -q .login)"
  fi
  printf '%s\n' "${GHWF_LOGIN}"
}

ghwf_project_title() {
  printf '%s\n' "${AURALIS_PROJECT_TITLE:-Portfolio}"
}

ghwf_project_json() {
  if [[ -z "${GHWF_PROJECT_JSON:-}" ]]; then
    GHWF_PROJECT_JSON="$(
      gh project list --owner "$(ghwf_repo_owner)" --format json
    )"
  fi
  printf '%s\n' "${GHWF_PROJECT_JSON}"
}

ghwf_project_number() {
  local project_number
  project_number="$(
    ghwf_project_json |
      jq -r --arg title "$(ghwf_project_title)" '.projects[] | select(.title == $title) | .number'
  )"
  [[ -n "${project_number}" && "${project_number}" != "null" ]] ||
    ghwf_die "project not found: $(ghwf_project_title)"
  printf '%s\n' "${project_number}"
}

ghwf_project_id() {
  local project_id
  project_id="$(
    ghwf_project_json |
      jq -r --arg title "$(ghwf_project_title)" '.projects[] | select(.title == $title) | .id'
  )"
  [[ -n "${project_id}" && "${project_id}" != "null" ]] ||
    ghwf_die "project id not found: $(ghwf_project_title)"
  printf '%s\n' "${project_id}"
}

ghwf_fields_json() {
  if [[ -z "${GHWF_FIELDS_JSON:-}" ]]; then
    GHWF_FIELDS_JSON="$(
      gh project field-list "$(ghwf_project_number)" --owner "$(ghwf_repo_owner)" --format json
    )"
  fi
  printf '%s\n' "${GHWF_FIELDS_JSON}"
}

ghwf_field_id() {
  local field_id
  field_id="$(
    ghwf_fields_json |
      jq -r --arg name "$1" '.fields[] | select(.name == $name) | .id'
  )"
  [[ -n "${field_id}" && "${field_id}" != "null" ]] ||
    ghwf_die "project field not found: $1"
  printf '%s\n' "${field_id}"
}

ghwf_field_option_id() {
  local option_id
  option_id="$(
    ghwf_fields_json |
      jq -r --arg field "$1" --arg option "$2" '
        .fields[]
        | select(.name == $field)
        | .options[]?
        | select(.name == $option)
        | .id
      '
  )"
  [[ -n "${option_id}" && "${option_id}" != "null" ]] ||
    ghwf_die "project option not found: $1 -> $2"
  printf '%s\n' "${option_id}"
}

ghwf_project_item_id_by_url() {
  local url="$1"
  gh project item-list "$(ghwf_project_number)" --owner "$(ghwf_repo_owner)" --format json |
    jq -r --arg url "${url}" '.items[] | select(.content.url == $url) | .id' |
    head -n1
}

ghwf_ensure_project_item() {
  local url="$1"
  local item_id

  item_id="$(ghwf_project_item_id_by_url "${url}")"
  if [[ -n "${item_id}" ]]; then
    printf '%s\n' "${item_id}"
    return
  fi

  gh project item-add "$(ghwf_project_number)" --owner "$(ghwf_repo_owner)" --url "${url}" --format json -q .id
}

ghwf_set_project_status() {
  local item_id="$1"
  local status_name="$2"

  gh project item-edit \
    --id "${item_id}" \
    --project-id "$(ghwf_project_id)" \
    --field-id "$(ghwf_field_id Status)" \
    --single-select-option-id "$(ghwf_field_option_id Status "${status_name}")" \
    >/dev/null
}

ghwf_issue_json() {
  gh issue view "$1" --repo "$(ghwf_repo_full_name)" --json body,labels,milestone,projectItems,assignees,title,number,url
}

ghwf_issue_status() {
  local issue_json="$1"
  jq -r --arg title "$(ghwf_project_title)" '
    .projectItems[]?
    | select(.title == $title)
    | .status.name // empty
  ' <<<"${issue_json}" | head -n1
}

ghwf_issue_delivery_body() {
  local issue_body="$1"
  local branch="$2"
  local pr_number="$3"
  local pr_url="$4"

  ISSUE_BODY="${issue_body}" BRANCH="${branch}" PR_NUMBER="${pr_number}" PR_URL="${pr_url}" python3 - <<'PY'
import os
import re

body = os.environ["ISSUE_BODY"]
branch = os.environ["BRANCH"]
pr_number = os.environ["PR_NUMBER"]
pr_url = os.environ["PR_URL"]

clean = re.sub(r"\n## Delivery\n.*?(?=\n## |\Z)", "", body, flags=re.S).rstrip()

print(
    f"{clean}\n\n## Delivery\n"
    f"- Branch: `{branch}`\n"
    f"- PR: [#{pr_number}]({pr_url})\n",
    end="",
)
PY
}

ghwf_update_issue_delivery() {
  local issue_number="$1"
  local branch="$2"
  local pr_number="$3"
  local pr_url="$4"
  local issue_json
  local issue_body_file

  issue_json="$(ghwf_issue_json "${issue_number}")"
  issue_body_file="$(mktemp)"
  trap 'rm -f "${issue_body_file}"' RETURN

  ghwf_issue_delivery_body \
    "$(jq -r '.body' <<<"${issue_json}")" \
    "${branch}" \
    "${pr_number}" \
    "${pr_url}" \
    >"${issue_body_file}"

  gh issue edit "${issue_number}" --repo "$(ghwf_repo_full_name)" --body-file "${issue_body_file}" >/dev/null
}

ghwf_ensure_label() {
  local label_name="$1"
  local color="$2"
  local description="$3"
  local repo

  repo="$(ghwf_repo_full_name)"

  if gh api "repos/${repo}/labels/${label_name}" >/dev/null 2>&1; then
    return
  fi

  gh api -X POST "repos/${repo}/labels" \
    -f name="${label_name}" \
    -f color="${color}" \
    -f description="${description}" \
    >/dev/null
}

ghwf_slugify() {
  tr '[:upper:]' '[:lower:]' <<<"$1" |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

ghwf_detect_milestone_title_from_branch() {
  local head_branch="$1"
  local head_slug

  head_slug="${head_branch#milestone/}"
  gh api "repos/$(ghwf_repo_full_name)/milestones?state=open&per_page=100" |
    jq -r --arg slug "${head_slug}" '
      .[]
      | select((.title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("(^-+|-+$)"; "")) == $slug)
      | .title
    ' |
    head -n1
}
