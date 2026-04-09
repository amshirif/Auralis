# Workflow Conventions

## Purpose

These conventions keep issue planning, branch flow, PR metadata, and project
tracking predictable across the portfolio repo.

## Working Cycle

- `main` only receives milestone PRs.
- milestone branches collect the work for one GitHub milestone.
- task branches merge into milestone branches.
- milestone branches merge into `main` after the milestone is complete.

In practice:

1. plan the work on a GitHub issue before implementation starts
2. branch from the active `milestone/*` branch
3. open a task PR into that milestone branch
4. repeat until the milestone issue is complete
5. open one milestone PR from `milestone/*` into `main`

Worktrees are optional in this repo. Use them only when they help local
execution or review; they are not required workflow state.

## Issue Planning Before Implementation

Every implementation task should start from a GitHub issue.

Task issues are not treated as ready until they have:

- an assignee
- a GitHub milestone
- a project card on `Portfolio`
- a project `Status`
- a parent/sub-issue relationship to the active milestone umbrella issue when
  the work belongs to one

`Portfolio` currently uses `Status` but does not have a `Track` or `Category`
field. If one is added later, treat it as required issue/PR workflow metadata
rather than optional bookkeeping.

Once a branch and PR exist, the issue body should include a `Delivery` section:

- `Branch: \`<branch>\``
- `PR: [#<number>](<url>)`

Use one canonical `PR:` line. Do not add a duplicate `PR URL:` entry.

## Task PR Rules

Task PRs should:

- target the active `milestone/*` branch
- have an assignee
- copy the linked issue labels where appropriate
- inherit the issue milestone
- have a project card on `Portfolio`
- carry a project `Status` of `In progress`
- include `Closes #<issue-number>` in the PR body

When GitHub `Development` links are unreliable, the issue `Delivery` section and
the PR `Closes #...` line are treated as the canonical linkage.

Use [`scripts/open-task-pr.sh`](/Users/amirshirif/Documents/personal/auralis/scripts/open-task-pr.sh)
to create task PRs with the expected metadata and delivery links in one step.

## Milestone PR Rules

Milestone PRs should:

- use `milestone/*` as the head branch
- target `main`
- have an assignee
- carry the `milestone` label
- have a project card on `Portfolio`
- use `In progress` status while open

Use [`scripts/open-milestone-pr.sh`](/Users/amirshirif/Documents/personal/auralis/scripts/open-milestone-pr.sh)
to create milestone PRs with the expected metadata in one step.

Main-branch guardrails in
[`main-pr-branch-guard.yml`](/Users/amirshirif/Documents/personal/auralis/.github/workflows/main-pr-branch-guard.yml)
enforce the parts of this checklist that GitHub Actions can verify.

## Branch Naming

### Milestone Branches

- `milestone/<slug>`

### Task Branches

- `<type>/<slug>`

Where `type` is typically one of:

- `feat`
- `fix`
- `chore`
- `docs`
- `research`

This repo already uses slug-based task branches broadly, so the workflow keeps
that convention instead of forcing issue numbers into branch names.

## Definition of Done

Work is not done when the code lands but the side cards are missing.

For task work, done means:

- issue metadata is complete
- issue `Delivery` section is current
- PR metadata matches the issue
- project cards/status are set correctly
- the milestone branch receives the task PR, not `main`
