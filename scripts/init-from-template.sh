#!/usr/bin/env bash
# Replace `<<PLACEHOLDER>>` tokens across the repo. Run once after creating a
# new repo from this template. Idempotent — re-running with the same args is
# a no-op once placeholders are replaced.

set -euo pipefail

usage() {
  cat <<USAGE
usage: $0 [--name <name>] [--desc <one-line>] [--org <gh-org>] \\
          [--repo <repo>] [--license MIT|Echo] [--copyright "Holder"]

All flags are optional; missing values prompt interactively.
USAGE
}

PROJECT_NAME=""
ONE_LINE_DESCRIPTION=""
ORG=""
REPO=""
LICENSE_KIND=""
COPYRIGHT_HOLDER=""
YEAR="$(date +%Y)"

while [ $# -gt 0 ]; do
  case "$1" in
    --name)        PROJECT_NAME="$2"; shift 2;;
    --desc)        ONE_LINE_DESCRIPTION="$2"; shift 2;;
    --org)         ORG="$2"; shift 2;;
    --repo)        REPO="$2"; shift 2;;
    --license)     LICENSE_KIND="$2"; shift 2;;
    --copyright)   COPYRIGHT_HOLDER="$2"; shift 2;;
    -h|--help)     usage; exit 0;;
    *)             echo "unknown arg: $1" >&2; usage; exit 2;;
  esac
done

ask() {
  local label="$1" var="$2" default="${3:-}"
  if [ -z "${!var}" ]; then
    if [ -n "$default" ]; then
      printf '%s [%s]: ' "$label" "$default"
    else
      printf '%s: ' "$label"
    fi
    read -r ans
    if [ -z "$ans" ] && [ -n "$default" ]; then ans="$default"; fi
    eval "$var=\$ans"
  fi
}

ask 'Project name'         PROJECT_NAME
ask 'One-line description' ONE_LINE_DESCRIPTION
ask 'GitHub org'           ORG     "ECHO-OMEGA-PRIME"
ask 'Repo name'            REPO    "$PROJECT_NAME"
ask 'License (MIT|Echo)'   LICENSE_KIND   "MIT"
ask 'Copyright holder'     COPYRIGHT_HOLDER "Echo Prime Tech LLC"

REPLACE() {
  local find="$1" repl="$2"
  # Use perl for cross-platform in-place edit; macOS sed -i requires '' arg.
  grep -rl --binary-files=without-match -- "$find" . \
    --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv \
    --exclude=init-from-template.sh --exclude=init-from-template.ps1 \
    | xargs -r perl -pi -e "s/\Q$find\E/$repl/g"
}

REPLACE '<<PROJECT_NAME>>'         "$PROJECT_NAME"
REPLACE '<<ONE_LINE_DESCRIPTION>>' "$ONE_LINE_DESCRIPTION"
REPLACE '<<ORG>>'                  "$ORG"
REPLACE '<<REPO>>'                 "$REPO"
REPLACE '<<LICENSE>>'              "$LICENSE_KIND"
REPLACE '<<COPYRIGHT_HOLDER>>'     "$COPYRIGHT_HOLDER"
REPLACE '<<YEAR>>'                 "$YEAR"

echo
echo "[init] placeholders substituted. Review with: git diff"
echo "[init] then commit: git add -A && git commit -m 'chore: instantiate from template'"
