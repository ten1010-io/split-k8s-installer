#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Repo guardrail — block force-push to main/master from Claude Code.
#
# Event : PreToolUse (matcher: Bash). Denies via permissionDecision:"deny".
# Deps  : none. Matches on the raw hook-input JSON (no jq) so it runs everywhere,
#         including Git Bash on Windows. Fails SAFE — blocks on ambiguous refs;
#         the deny message explains how to override.
#
# Why   : 2026-07-07, a force-push to main clobbered an already-merged PR (#146),
#         silently removing a shipped fix. This blocks that class of mistake at
#         the point every developer shares: Claude Code. It is defense-in-depth,
#         NOT a hard guarantee — pair with server-side branch protection.
#
# Scope : blocks ONLY force pushes (--force / --force-with-lease /
#         --force-if-includes / -f / +refspec) whose target is main or master.
#         Normal pushes and force-pushes to feature branches are allowed.
# ─────────────────────────────────────────────────────────────────────────────
input=$(cat 2>/dev/null)

# Fast exit: only inspect git push commands.
printf '%s' "$input" | grep -Eq 'push'  || exit 0
printf '%s' "$input" | grep -Eq 'git'   || exit 0

# 1) Is it a force push? (force flag, or a leading-'+' refspec = forced update)
is_force=0
printf '%s' "$input" | grep -Eq -- '--force(-with-lease|-if-includes)?([^A-Za-z]|$)' && is_force=1
printf '%s' "$input" | grep -Eq -- '(^|[[:space:]])-[A-Za-z]*f([[:space:]]|\\?"|$)'   && is_force=1
printf '%s' "$input" | grep -Eq -- '\+[^[:space:]"]*(main|master)'                    && is_force=1
[ "$is_force" -eq 1 ] || exit 0

# 2) Does it target main/master? explicit ref token, else the current branch.
#    Preceding boundary = space | ':' | '+'  (ref separators) — NOT '/' or '-',
#    so 'fix/main-nav' style feature branches are NOT matched.
targets=0
printf '%s' "$input" | grep -Eq -- '(^|[[:space:]:+])(main|master)([^A-Za-z0-9_/-]|\\?"|$)' && targets=1
if [ "$targets" -eq 0 ]; then
  cur=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  case "$cur" in main|master) targets=1 ;; esac
fi
[ "$targets" -eq 1 ] || exit 0

# 3) Deny.
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"[repo guardrail] main/master 강제 push 차단 — 병합된 PR을 덮어써 유실시키는 사고 방지(AIP 2026-07-07). PR 또는 feature 브랜치로 진행하세요. 정말 필요하면 Claude Code 밖 터미널에서 직접 실행하세요. 규칙 위치: .claude/hooks/block-main-force-push.sh"}}'
exit 0
