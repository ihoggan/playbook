#!/usr/bin/env bash
#
# new-project.sh — start a project properly, without remembering anything.
#
#     ~/playbook/tools/new-project.sh                    # asks
#     ~/playbook/tools/new-project.sh myproject          # doesn't
#     ~/playbook/tools/new-project.sh myproject ~/code   # somewhere else
#
#     ~/playbook/tools/new-project.sh --dry-run myproject
#         Print every command it would run, and stop. This is what
#         MAKERS_INSTRUCTIONS.md's "by hand" route now shows, so the by-hand
#         steps are DERIVED from the script rather than a second copy that can
#         drift away from it.
#
#     ~/playbook/tools/new-project.sh --files-only ~/oldproject
#         Copy the playbook files into a directory that already exists, and do
#         nothing else — no venv, no git, no documents, and nothing that would
#         overwrite existing work. This is what ADOPT_EXISTING.md calls.
#
#     --no-venv    skip the venv (it is the slow, network-touching part;
#                  useful in CI and when adopting into an existing venv)
#
# WHAT IT CREATES is not written down here. It is read from SCAFFOLD_MANIFEST
# in the playbook root, which is the single place that list lives.
#
# It does NOT create the GitHub repo and does NOT push. Those stay manual, so
# a script can never put something in the wrong place. It refuses to touch a
# directory that already exists.

set -euo pipefail

PLAYBOOK="${PLAYBOOK:-$HOME/playbook}"
MANIFEST="$PLAYBOOK/SCAFFOLD_MANIFEST"

DRY=0
FILES_ONLY=0
MAKE_VENV=1
NAME=""
PARENT="$HOME"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)    DRY=1 ;;
        --files-only) FILES_ONLY=1; MAKE_VENV=0 ;;
        --no-venv)    MAKE_VENV=0 ;;
        -h|--help)    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)           echo "REFUSING: unknown option '$1'"; exit 1 ;;
        *)            if [ -z "$NAME" ]; then NAME="$1"; else PARENT="$1"; fi ;;
    esac
    shift
done

bold=$'\033[1m'; dim=$'\033[2m'; off=$'\033[0m'

[ -f "$PLAYBOOK/PLAYBOOK.md" ] || {
    echo "REFUSING: no PLAYBOOK.md at $PLAYBOOK"
    echo "Set PLAYBOOK=/path/to/playbook if it lives somewhere else."
    exit 1
}
[ -f "$MANIFEST" ] || {
    echo "REFUSING: no SCAFFOLD_MANIFEST at $MANIFEST"
    echo "That file is what says which files a project gets. Without it this"
    echo "script would have to carry its own copy of the list, which is the"
    echo "exact drift the manifest exists to prevent."
    exit 1
}

# --files-only takes a PATH that must already exist; everything else takes a
# NAME for a directory that must not.
if [ "$FILES_ONLY" -eq 1 ]; then
    [ -n "$NAME" ] || { echo "REFUSING: --files-only needs a directory."; exit 1; }
    DEST="$NAME"
    NAME="$(basename "$(cd "$DEST" 2>/dev/null && pwd || echo "$DEST")")"
    [ -d "$DEST" ] || { echo "REFUSING: $DEST does not exist."; exit 1; }
else
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
    if [ -e "$DEST" ] && [ "$DRY" -eq 0 ]; then
        echo "REFUSING: $DEST already exists."
        echo "Pick another name, or remove it first if it is genuinely disposable."
        echo "To add the playbook files to an existing project, use --files-only."
        exit 1
    fi
fi

YEAR="$(date +%Y)"
HOLDER="$(git config --get user.name 2>/dev/null || true)"
[ -n "$HOLDER" ] || HOLDER="$(id -un)"

say () { if [ "$DRY" -eq 1 ]; then echo "$*"; fi; }
run () { if [ "$DRY" -eq 1 ]; then echo "$*"; else eval "$*"; fi; }

# ---------------------------------------------------------------------------
# The manifest drives everything below.
# ---------------------------------------------------------------------------
manifest_lines () {
    grep -v '^[[:space:]]*#' "$MANIFEST" | grep -v '^[[:space:]]*$'
}

say "# files, from $MANIFEST"
[ "$DRY" -eq 1 ] || echo "==> $( [ "$FILES_ONLY" -eq 1 ] && echo "copying into" || echo "creating" ) $DEST"
run "mkdir -p '$DEST'"

while IFS= read -r line; do
    src="${line%%:*}"
    rest="${line#*:}"
    dst="${rest%%:*}"
    flags="${rest#*:}"
    [ "$flags" = "$rest" ] && flags=""

    case "$flags" in
        *new-only*) [ "$FILES_ONLY" -eq 1 ] && continue ;;
    esac

    [ -f "$PLAYBOOK/$src" ] || { echo "REFUSING: manifest lists $src, which does not exist."; exit 1; }

    dstdir="$(dirname "$DEST/$dst")"
    [ "$dstdir" = "$DEST" ] || run "mkdir -p '$dstdir'"

    case "$flags" in
        *render*)
            run "sed -e 's|__NAME__|$NAME|g' -e 's|__YEAR__|$YEAR|g' -e 's|__HOLDER__|$HOLDER|g' '$PLAYBOOK/$src' > '$DEST/$dst'"
            ;;
        *)
            run "cp '$PLAYBOOK/$src' '$DEST/$dst'"
            ;;
    esac
done <<EOF
$(manifest_lines)
EOF

run "chmod +x '$DEST/tools/mutate.sh'"

if [ "$FILES_ONLY" -eq 1 ]; then
    echo
    echo "  Playbook files copied into $DEST."
    echo "  Nothing else was touched. Next: ADOPT_EXISTING.md step 2 —"
    echo "  establish a baseline BEFORE changing anything."
    exit 0
fi

say ""
say "# .gitignore and requirements.txt"
[ "$DRY" -eq 1 ] || echo "==> .gitignore and requirements.txt"
run "printf '__pycache__/\\n*.pyc\\n.venv/\\nbuild/\\ndist/\\n.DS_Store\\n' > '$DEST/.gitignore'"
run "printf '# Dependencies — these, and nothing else.\\n# Adding to this file needs an explicit decision, not a convenience.\\n' > '$DEST/requirements.txt'"

say ""
say "# the documents, empty (much harder to start at revision forty)"
[ "$DRY" -eq 1 ] || echo "==> empty documents (much harder to start at revision forty)"
run "printf '# Changelog\\n\\nWhat changed and WHY — including fixes that were wrong\\nfirst, and what the wrong one taught.\\n\\n---\\n' > '$DEST/CHANGELOG.md'"
run "printf '# Known issues\\n\\nOpen problems, each shipped with its diagnosis so the next\\nperson starts from the answer rather than the symptom.\\n\\n---\\n' > '$DEST/KNOWN_ISSUES.md'"
run "printf '# Handoff — $NAME\\n\\n**Status:** scaffolded, spine only.\\n\\nCurrent state, architecture doctrine, and the standing\\nexceptions that must not be tidied away.\\n\\n---\\n' > '$DEST/HANDOFF.md'"

# ---------------------------------------------------------------------------
# Prove the spine works and pin the numbers CI will enforce.
#
# This is the difference between a workflow that is green on the first push
# and one that is red until you get round to it. The numbers are READ OFF A
# REAL RUN, never guessed -- which is the same rule the projects themselves
# are held to.
# ---------------------------------------------------------------------------
say ""
say "# prove the spine and pin the CI numbers from a real run"
if [ "$DRY" -eq 0 ]; then
    echo "==> proving the spine"
    ( cd "$DEST" && python3 -m py_compile main.py ) || {
        echo "REFUSING: the spine does not compile."; exit 1; }

    # THE SELFTEST IS EXPECTED TO BE ABLE TO FAIL, so its exit status must not
    # be allowed to kill this script. Under `set -euo pipefail` it did: a
    # failing spine made the COUNT assignment inherit exit 1 and the script
    # died on that line -- BEFORE the guard below, which was written to report
    # exactly this and could never be reached. A guard placed after the thing
    # it guards against is not a guard.
    #
    # Capture once, into a variable, and read the numbers off that. Running it
    # twice also risked two different answers being reported as one.
    ST_OUT="$( cd "$DEST" && python3 main.py --selftest 2>&1 )" || true
    COUNT="$(printf '%s\n' "$ST_OUT" | grep -c '\[PASS\]' || true)"
    FAILN="$(printf '%s\n' "$ST_OUT" | grep -c '\[FAIL\]' || true)"

    if [ "$FAILN" -ne 0 ] || [ "$COUNT" -eq 0 ]; then
        echo "REFUSING: the spine does not pass its own selftest ($COUNT pass, $FAILN fail)."
        echo "Pinning CI to the numbers of a failing run would make the workflow"
        echo "green against a spine that does not work."
        printf '%s\n' "$ST_OUT" | grep '\[FAIL\]' | sed 's/^/    /'
        exit 1
    fi

    ( cd "$DEST" && python3 main.py --smoke 90 >/dev/null ) || {
        echo "REFUSING: the spine's smoke test does not pass."; exit 1; }
    ( cd "$DEST" && python3 main.py --snap /tmp/_scaffold_baseline.out >/dev/null ) || {
        echo "REFUSING: the spine cannot write a baseline."; exit 1; }
    MD5="$(md5sum /tmp/_scaffold_baseline.out | cut -d' ' -f1)"
    rm -f /tmp/_scaffold_baseline.out
    rm -rf "$DEST/__pycache__"
    sed -i -e "s/^  SELFTEST_COUNT: .*/  SELFTEST_COUNT: $COUNT/" \
           -e "s/^  BASELINE_MD5: .*/  BASELINE_MD5: \"$MD5\"/" \
           "$DEST/.github/workflows/validate.yml"
    echo "    selftest $COUNT assertions, 0 failed"
    echo "    smoke    90 iterations, exit 0"
    echo "    baseline $MD5"
else
    echo "cd '$DEST' && python3 main.py --selftest   # read the count off it"
    echo "cd '$DEST' && python3 main.py --snap /tmp/b.out && md5sum /tmp/b.out"
    echo "# then put those two numbers into .github/workflows/validate.yml"
fi

if [ "$MAKE_VENV" -eq 1 ]; then
    say ""
    say "# the environment — venv, activate, upgrade pip, THEN install"
    [ "$DRY" -eq 1 ] || echo "==> virtual environment"
    run "python3 -m venv '$DEST/.venv'"
    run ". '$DEST/.venv/bin/activate' && python -m pip install --upgrade pip >/dev/null 2>&1"
fi

say ""
say "# git, local. Named files, never 'git add -A'."
[ "$DRY" -eq 1 ] || echo "==> git"
run "cd '$DEST' && git init -q -b main"

# The add list is the manifest destinations plus the generated files. Still
# named explicitly -- never 'git add -A' -- but derived, not retyped.
ADDLIST=""
while IFS= read -r line; do
    rest="${line#*:}"
    dst="${rest%%:*}"
    ADDLIST="$ADDLIST '$dst'"
done <<EOF
$(manifest_lines)
EOF
ADDLIST="$ADDLIST '.gitignore' 'CHANGELOG.md' 'KNOWN_ISSUES.md' 'HANDOFF.md' 'requirements.txt'"

if [ "$DRY" -eq 1 ]; then
    echo "cd '$DEST' && git add$ADDLIST"
    echo "cd '$DEST' && git commit -m 'scaffold from playbook'"
    echo
    echo "# --dry-run: nothing above was executed."
    exit 0
fi

( cd "$DEST" && eval "git add$ADDLIST" )
if ( cd "$DEST" && git commit -qm "scaffold from playbook" 2>/dev/null ); then
    COMMIT="$( cd "$DEST" && git log --oneline -1 )"
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
( cd "$DEST" && git ls-files | sed 's/^/    /' )
[ "$MAKE_VENV" -eq 1 ] && echo "    .venv/            ${dim}(gitignored, rebuildable from requirements.txt)${off}"
echo
echo "  ${bold}THE SPINE ALREADY PASSES${off}"
echo "    selftest  $COUNT assertions, 0 failed"
echo "    smoke     90 iterations, exit 0"
echo "    baseline  $MD5"
echo "    ${dim}both numbers are already pinned in validate.yml, so CI is${off}"
echo "    ${dim}green on the FIRST push. Bump them as you add assertions.${off}"
echo
echo "  ${bold}REPO${off}"
echo "    branch  $( cd "$DEST" && git branch --show-current )"
echo "    commit  $COMMIT"
echo "    remote  ${dim}none yet — see step 1${off}"
echo
echo "  ${bold}NEXT${off}"
cat <<ENDNEXT
    1. Create the empty repo at https://github.com/new
       Name it "$NAME". NO README, licence or .gitignore —
       the scaffold already made all three and they would collide.

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

    6. Replace the spine in main.py with the real thing, one
       assertion at a time. Mutation-test each one:
         export SRC=main.py CMD=--selftest && . tools/mutate.sh
         run_mutant "description" "old text" "new text"
         mutation_summary
ENDNEXT
echo
