#!/usr/bin/env bash
# Run all appfront-migrate eval cases.
# Usage: ./run-evals.sh [case-dir-name]  (omit arg to run all)
# Results are printed to stdout for manual assertion review.

set -euo pipefail

EVALS_DIR="$(cd "$(dirname "$0")" && pwd)"
MIGRATE_DIR="$EVALS_DIR/migrate"

run_case() {
  local case_dir="$1"
  local case_name
  case_name="$(basename "$case_dir")"

  echo "════════════════════════════════════════════════════════════"
  echo "CASE: $case_name"
  echo "════════════════════════════════════════════════════════════"

  if [ ! -f "$case_dir/prompt.md" ]; then
    echo "  [SKIP] prompt.md not found"
    return
  fi

  if [ -z "$(ls -A "$case_dir/input" 2>/dev/null)" ]; then
    echo "  [SKIP] input/ is empty — add source MTA files before running"
    return
  fi

  local output_dir="$case_dir/output"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local work_dir="$output_dir/$timestamp"
  local output_file="$output_dir/$timestamp.md"

  # Copy input project to isolated working directory so originals are never modified
  # Find the actual project subdirectory (skip .gitkeep and other non-directory files)
  local project_dir
  project_dir="$(find "$case_dir/input" -mindepth 1 -maxdepth 1 -type d | head -1)"
  if [ -z "$project_dir" ]; then
    echo "  [SKIP] no project directory found in input/"
    return
  fi
  mkdir -p "$work_dir"
  cp -r "$project_dir" "$work_dir/"

  # Allow Claude to write files without interactive permission prompts
  mkdir -p "$work_dir/.claude"
  cat > "$work_dir/.claude/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Write(**)", "Edit(**)", "Bash(**)"]
  }
}
EOF

  echo ""
  echo "── CLAUDE OUTPUT ──────────────────────────────────────────"
  (cd "$work_dir" && claude --print --permission-mode bypassPermissions < "$case_dir/prompt.md") > "$output_file" 2>&1 || true
  cat "$output_file"

  echo ""
  echo "── ASSERTIONS (review manually) ───────────────────────────"
  cat "$case_dir/assertions.md"
  echo ""
  echo "  [OUTPUT SAVED] $output_file"
  echo "  [MIGRATED FILES] $work_dir"
}

if [ "${1:-}" != "" ]; then
  run_case "$MIGRATE_DIR/$1"
else
  for case_dir in "$MIGRATE_DIR"/case-*/; do
    run_case "$case_dir"
  done
fi
