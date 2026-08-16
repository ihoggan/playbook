#!/usr/bin/env bash
#
# new-project.sh — start a project properly, without remembering anything.
#
#     ~/playbook/tools/new-project.sh              # asks
#     ~/playbook/tools/new-project.sh myproject    # doesn't
#     ~/playbook/tools/new-project.sh myproject ~/code
#
# Creates the directory, the venv, the git repo, and copies in the playbook,
# the CI workflow and the mutation harness. Then tells you what it made and
# what to do next.
#
# It does NOT create the GitHub repo and does NOT push. Those stay manual, so
# a script can never put something in the wrong place. It refuses to touch a
# directory that already exists.

set -euo pipefail

PLAYBOOK="${PLAYBOOK:-$HOME/playbook}"
NAME="${1:-}"
PARENT="${2:-$HOME}"

bold=$'\033[1m'; dim=$'\033[2m'; off=$'\033[0m'

if [ ! -f "$PLAYBOOK/PLAYBOOK.md" ]; then
    echo "REFUSING: no PLAYBOOK.md at $PLAYBOOK"
    echo "Set PLAYBOOK=/path/to/playbook if it lives somewhere else."
    exit 1
fi

if [ -z "$NAME" ]; then
    echo
    echo "  ${bold}Howdy Maker.${off}"
    echo
    echo "  What's this project going to be called?"
    printf '  > '
    read -r NAME
    [ -z "$NAME" ] && { echo "  No name, no project. Nothing done."; exit 2; }

    echo
    echo "  Where should it live? ${dim}[$PARENT/$NAME]${off}"
    printf '  > '
    read -r WHERE
    [ -n "$WHERE" ] && PARENT="$WHERE"
    echo
fi

# Spaces in a project name become a lifetime of quoting. Say so now.
case "$NAME" in
    *" "*) echo "REFUSING: '$NAME' contains a space. Use a hyphen."; exit 1 ;;
esac

DEST="$PARENT/$NAME"

if [ -e "$DEST" ]; then
    echo "REFUSING: $DEST already exists."
    echo "Pick another name, or remove it first if it is genuinely disposable."
    exit 1
fi

echo "==> creating $DEST"
mkdir -p "$DEST/.github/workflows" "$DEST/tools"
cd "$DEST"

echo "==> copying the playbook, templates and harness"
cp "$PLAYBOOK/PLAYBOOK.md" .
cp "$PLAYBOOK/MAKERS_INSTRUCTIONS.md" .
cp "$PLAYBOOK/.gitattributes" .
cp "$PLAYBOOK/templates/validate.yml" .github/workflows/
cp "$PLAYBOOK/templates/CONTRIBUTING.md" ./CONTRIBUTING.md
cp "$PLAYBOOK/tools/mutate.sh" "$PLAYBOOK/tools/_mutate_apply.py" tools/
chmod +x tools/mutate.sh

echo "==> .gitignore and requirements.txt"
printf '__pycache__/\n*.pyc\n.venv/\nbuild/\ndist/\n' > .gitignore
cat > requirements.txt <<'ENDREQ'
# Dependencies — these, and nothing else.
# Adding to this file needs an explicit decision, not a convenience.
ENDREQ

echo "==> empty documents (much harder to start at revision forty)"
printf '# Changelog\n\nWhat changed and WHY — including fixes that were wrong\nfirst, and what the wrong one taught.\n\n---\n' > CHANGELOG.md
printf '# Known issues\n\nOpen problems, each shipped with its diagnosis so the next\nperson starts from the answer rather than the symptom.\n\n---\n' > KNOWN_ISSUES.md
printf '# Handoff — %s\n\n**Status:** not started.\n\nCurrent state, architecture doctrine, and the standing\nexceptions that must not be tidied away.\n\n---\n' "$NAME" > HANDOFF.md

echo "==> virtual environment"
python3 -m venv .venv
# shellcheck disable=SC1091
. .venv/bin/activate
python -m pip install --upgrade pip >/dev/null 2>&1
PIPV="$(python -m pip --version | cut -d' ' -f2)"

echo "==> git"
git init -q -b main
git add .gitattributes .gitignore PLAYBOOK.md MAKERS_INSTRUCTIONS.md \
        CONTRIBUTING.md CHANGELOG.md KNOWN_ISSUES.md HANDOFF.md \
        requirements.txt .github tools
if git commit -qm "scaffold from playbook" 2>/dev/null; then
    COMMIT="$(git log --oneline -1)"
else
    COMMIT="(not committed — set git user.name / user.email, then commit)"
fi

# ---------------------------------------------------------------------------
# The advisory. What exists, and what is true about it.
# ---------------------------------------------------------------------------
echo
echo "────────────────────────────────────────────────────────────"
echo "  ${bold}$NAME${off} is ready at ${bold}$DEST${off}"
echo "────────────────────────────────────────────────────────────"
echo
echo "  ${bold}LOCAL FILES${off}"
git ls-files | sed 's/^/    /'
echo "    .venv/            ${dim}(gitignored, rebuildable from requirements.txt)${off}"
echo
echo "  ${bold}ENVIRONMENT${off}"
echo "    python  $(python --version 2>&1 | cut -d' ' -f2)   pip $PIPV"
echo "    venv    $DEST/.venv"
echo
echo "  ${bold}REPO${off}"
echo "    branch  $(git branch --show-current)"
echo "    commit  $COMMIT"
echo "    remote  ${dim}none yet — see step 1${off}"
echo
echo "  ${bold}NEXT${off}"
cat <<ENDNEXT
    1. Create the empty repo at https://github.com/new
       Name it "$NAME". NO README, licence or .gitignore —
       you already have them and they would collide.

    2. cd $DEST
       git remote add origin https://github.com/<you>/$NAME.git
       git push -u origin main

    3. Verify from a FRESH CLONE, not from this directory:
       cd /tmp && rm -rf verify && git clone <url> verify && cd verify \\
         && git status --porcelain && echo "(empty = clean)"

    4. Every session from now on starts with:
       cd $DEST && . .venv/bin/activate

    5. Open the first session with:
       "New project. Read PLAYBOOK.md and MAKERS_INSTRUCTIONS.md
        in the repo first — that's how we work. Then HANDOFF.md."

    6. Before features: build the scaffolding everything rests on —
       a --selftest that reports a COUNT, a --smoke test, and a
       deterministic baseline you can hash. Then fill in
       SELFTEST_COUNT and BASELINE_MD5 in
       .github/workflows/validate.yml.
ENDNEXT
echo
