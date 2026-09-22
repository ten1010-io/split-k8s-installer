#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Repo convention — require Assignee + Milestone when opening a PR.
#
# Event : PreToolUse (matcher: Bash). Denies via permissionDecision:"deny".
# Deps  : none. Matches on the raw hook-input JSON (no jq) so it runs everywhere,
#         including Git Bash on Windows. Fails OPEN — an unparseable command is
#         allowed through, because a missed label is cheap and a false block is not.
#
# Why   : PRs land without an owner or a release bucket, so 5.1.0 scope has to be
#         reconstructed by hand at release time. The fields are one flag each at
#         creation and tedious to backfill later.
#
# Scope : inspects ONLY `gh pr create`. Skips --web (metadata is picked in the
#         browser form) and --dry-run. `gh pr edit` is untouched — that is the
#         documented way to fix a PR that is already open.
# ─────────────────────────────────────────────────────────────────────────────
input=$(cat 2>/dev/null)

# Fast exit: only inspect `gh pr create`.
printf '%s' "$input" | grep -Eq 'gh'                      || exit 0
printf '%s' "$input" | grep -Eq 'pr[[:space:]]+create'    || exit 0

# Browser flow fills these in the form; dry-run creates nothing.
printf '%s' "$input" | grep -Eq -- '(--web|--dry-run)([^A-Za-z-]|$)' && exit 0
printf '%s' "$input" | grep -Eq -- '(^|[[:space:]])-[A-Za-z]*w([[:space:]]|\\?"|$)' && exit 0

# Long form (--x, --x=v), or the short flag as its own token, or last in a bundle
# of booleans (-da @me). `-am v5.1.0` is NOT a pass: both flags take a value, so
# pflag reads "m" as the assignee and never sets the milestone — correctly denied.
has_flag() {  # $1 = long name, $2 = short letter
  printf '%s' "$input" | grep -Eq -- "--$1([[:space:]=]|\\\\?\")" && return 0
  printf '%s' "$input" | grep -Eq -- "(^|[[:space:]])-[A-Za-z]*$2([[:space:]]|\\\\?\"|$)" && return 0
  return 1
}

missing=""
has_flag assignee  a || missing="Assignee(--assignee @me)"
has_flag milestone m || missing="${missing:+$missing, }Milestone(--milestone <릴리즈>)"
[ -n "$missing" ] || exit 0

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"[repo convention] PR 생성에 %s 누락 — 릴리즈 스코프 집계와 담당자 추적에 필요합니다. 예: gh pr create --assignee @me --milestone v5.1.0 --base main --title ... 마일스톤 목록은 gh api repos/:owner/:repo/milestones 로 확인하세요. 웹 UI 로 만들 경우 --web 를 쓰면 이 검사를 건너뜁니다. 규칙 위치: .claude/hooks/require-pr-metadata.sh"}}\n' "$missing"
exit 0
