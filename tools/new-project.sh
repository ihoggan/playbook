#!/usr/bin/env bash
#
# new-project.sh — scaffold a new project from the playbook.
#
#     ~/playbook/tools/new-project.sh myproject
#     ~/playbook/tools/new-project.sh myproject ~/code   # different parent dir
#
# Creates the directory, the venv, the git repo, and copies in the playbook,
# the CI workflow and the mutation harness. Prints what it did and what to do
# next. It does NOT create the GitHub repo or push — that stays manual, so
# nothing gets pushed to the wrong place by a script.
#
# Safe to read before running. It refuses to touch an existing directory.

set -euo pipefail

NAME="${1:-}"
PARENT="${2:-$HOME}"
PLAYBOOK="${PLAYBOOK:-$HOME/playbook}"

if [ -z "$NAME" ]; then
    echo "usage: new-project.sh <name> [parent-dir]"
    exit 2
fi

DEST="$PARENT/$NAME"

if [ -e "$DEST" ]; then
    echo "REFUSING: $DEST already exists."
    echo "Pick another name, or remove it first if it is genuinely disposable."
    exit 1
fi

if [ ! -f "$PLAYBOOK/PLAYBOOK.md" ]; then
    echo "REFUSING: no PLAYBOOK.md at $PLAYBOOK"
    echo "Set PLAYBOOK=/path/to/playbook if it lives somewhere else."
    exit 1
fi

echo "==> creating $DEST"
mkdir -p "$DEST/.github/workflows" "$DEST/tools"
cd "$DEST"

echo "==> copying the playbook and its templates"
cp "$PLAYBOOK/PLAYBOOK.md" .
cp "$PLAYBOOK/.gitattributes" .
cp "$PLAYBOOK/templates/validate.yml" .github/workflows/
cp "$PLAYBOOK/templates/CONTRIBUTING.md" ./CONTRIBUTING.md
cp "$PLAYBOOK/tools/mutate.sh" "$PLAYBOOK/tools/_mutate_apply.py" tools/
chmod +x tools/mutate.sh

echo "==> .gitignore"
cat > .gitignore <<'ENDIGNORE'
__pycache__/
*.pyc
.venv/
build/
dist/
ENDIGNORE

echo "==> requirements.txt"
cat > requirements.txt <<'ENDREQ'
# Dependencies — these, and nothing else.
# Adding to this file needs an explicit decision, not a convenience.
ENDREQ

echo "==> empty documents (much harder to start at revision forty)"
printf '# Changelog\n\nWhat changed and WHY — including fixes that were wrong first,\nand what the wrong one taught.\n\n---\n' > CHANGELOG.md
printf '# Known issues\n\nOpen problems, each shipped with its diagnosis so the next person\nstarts from the answer rather than the symptom.\n\n---\n' > KNOWN_ISSUES.md
printf '# Handoff\n\n**Status:** not started.\n\nCurrent state, architecture doctrine, and the standing exceptions\nthat must not be tidied away.\n\n---\n' > HANDOFF.md

echo "==> virtual environment"
python3 -m venv .venv
# shellcheck disable=SC1091
. .venv/bin/activate
python -m pip install --upgrade pip >/dev/null
echo "    pip $(python -m pip --version | cut -d' ' -f2) in $DEST/.venv"

echo "==> git"
git init -q -b main
git add .gitattributes .gitignore PLAYBOOK.md CONTRIBUTING.md \
        CHANGELOG.md KNOWN_ISSUES.md HANDOFF.md requirements.txt \
        .github tools
git -c user.useConfigOnly=false commit -qm "scaffold from playbook" || {
    echo "    (commit skipped — set user.name/user.email and commit manually)"
}

cat <<ENDNEXT

------------------------------------------------------------------
$NAME is scaffolded at $DEST

NEXT, IN THIS ORDER:

  1. Create the empty repo at https://github.com/new — name it "$NAME",
     with NO README, licence or .gitignore (you already have them).

  2. cd $DEST && git remote add origin \\
       https://github.com/<you>/$NAME.git && git push -u origin main

  3. Every session from now on starts with:
       cd $DEST && . .venv/bin/activate

  4. Open the first session with:
       "New project. Read PLAYBOOK.md in the repo first — that's how
        we work. Then HANDOFF.md for where things are."

  5. Before writing code, build the scaffolding that everything else
     rests on: a --selftest that reports a COUNT, a --smoke test, and
     a deterministic baseline you can hash. Then fill in
     SELFTEST_COUNT and BASELINE_MD5 in
     .github/workflows/validate.yml.
------------------------------------------------------------------
ENDNEXT
