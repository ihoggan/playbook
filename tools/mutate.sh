#!/usr/bin/env bash
#
# mutate.sh — mutation-test helper.
#
# An assertion that cannot fail is not an assertion. The only way to know is to
# break the code deliberately and check that the assertion notices.
#
# THIS SCRIPT'S JOB IS TO HAND YOU A VERDICT, NOT A NUMBER TO INTERPRET.
#
# The earlier version printed the last line of the mutated run and left you to
# read it. A caught mutant printed "0 passed" and a survivor printed "3 passed"
# — the same shape, told apart only by a count you had to remember. That is the
# same failure this script exists to prevent, one layer up: a result you can
# misread is barely better than a result that never happened.
#
# So: a baseline run first, so the harness knows the expected count itself, and
# then one of five verdicts per mutant.
#
#   CAUGHT        an assertion failed. The mutant was detected. Good.
#   SURVIVED      the suite passed unchanged. THE ASSERTION IS NOT DOING ITS
#                 JOB — usually circular, or an inequality where the contract
#                 is exact, or written against data that cannot reach the
#                 branch.
#   CRASHED       the code did not run at all. NOT A RESULT: the suite never
#                 reached the assertion, so this says nothing about it. Pick a
#                 mutation that leaves the module importable.
#   ANCHOR FAILED the search text did not match exactly once. NOT A RESULT.
#   NOT APPLIED   the file came out byte-identical. NOT A RESULT.
#
# Usage:
#     export SRC=main.py CMD=--selftest
#     . tools/mutate.sh
#     mutation_baseline
#     run_mutant "off-by-one in the seeding" "range(n)" "range(n - 1)"
#     run_mutant "wrong constant"            "* 37"     "* 38"
#     mutation_summary          # non-zero exit if anything SURVIVED
#
# mutation_baseline is optional; run_mutant will take it automatically on
# first use. Take it explicitly when you want to see the starting numbers.

SRC="${SRC:-main.py}"           # file under test
WORK="${WORK:-/tmp/mutwork}"    # scratch dir the mutated copy runs in
CMD="${CMD:---selftest}"        # how to run the suite
TREE="${TREE:-}"                # optional: stage a whole directory
RUN="${RUN:-}"                  # optional: what to run inside it

# TREE/RUN are for a project whose suite needs more than one file next to it --
# a tool that reads a manifest from its repo root, a package with data files.
# Without them the harness stages SRC plus its sibling .py files, which is
# right for a single-module project and silently wrong for anything larger:
# the copy runs, cannot find what it needs, and every mutant reports CRASHED.
#
#     export TREE=. SRC=tools/new-project.sh RUN="python3 tools/selftest.py"

MUT_BASE_PASS=""                # assertions the clean suite reports
MUT_SURVIVORS=0
MUT_NONRESULTS=0
MUT_CAUGHT=0

# Finding the helper. This was once ${BASH_SOURCE[0]} alone, which zsh does not
# define — sourcing from zsh left the path empty, python could not find the
# helper, and EVERY mutant reported ANCHOR FAILED: a message blaming the anchor
# for a path problem. Replacing it with a plain search then went too far the
# other way and dropped the most reliable location of all, the directory this
# file is in, so sourcing it from any other working directory failed. Both now:
# ask the shell where this file is, and fall back to a search.
# Where THIS file is, whichever shell sourced it. bash and zsh each have an
# answer and neither understands the other's syntax, so the zsh form is hidden
# behind eval -- bash would fail on ${(%):-%x} at parse time.
_mut_self_dir () {
    local self=""
    if [ -n "${BASH_SOURCE:-}" ]; then
        self="${BASH_SOURCE[0]}"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        eval 'self="${(%):-%x}"'
    fi
    [ -n "$self" ] || return 1
    ( cd "$(dirname "$self")" 2>/dev/null && pwd )
}

_mut_helper () {
    local c
    local mine; mine="$(_mut_self_dir 2>/dev/null || true)"
    for c in "${MUT_HELPER:-}" \
             "${mine:+$mine/_mutate_apply.py}" \
             "$PWD/tools/_mutate_apply.py" \
             "$PWD/_mutate_apply.py" \
             "$HOME/playbook/tools/_mutate_apply.py"; do
        [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return 0; }
    done
    echo "NO HELPER: _mutate_apply.py not found. Looked in \$MUT_HELPER, beside" >&2
    echo "  mutate.sh itself, ./tools/, ./ and ~/playbook/tools/." >&2
    echo "  Set MUT_HELPER=/path/to/_mutate_apply.py." >&2
    return 1
}

# Where the mutated copy of SRC lands inside WORK.
_mut_target () {
    if [ -n "$TREE" ]; then printf '%s' "$WORK/$SRC"
    else printf '%s' "$WORK/$(basename "$SRC")"; fi
}

# Stage a clean copy: the whole tree if TREE is set, otherwise the file under
# test plus its sibling modules.
_mut_stage () {
    rm -rf "$WORK" && mkdir -p "$WORK"
    if [ -n "$TREE" ]; then
        ( cd "$TREE" && tar cf - --exclude=.git --exclude=__pycache__ . ) \
            | ( cd "$WORK" && tar xf - )
        return
    fi
    local base; base="$(basename "$SRC")"
    cp "$SRC" "$WORK/$base"
    local f
    for f in "$(dirname "$SRC")"/*.py; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "$base" ] || cp "$f" "$WORK/" 2>/dev/null
    done
}

_mut_run () {
    if [ -n "$RUN" ]; then
        ( cd "$WORK" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
            eval "$RUN" 2>&1 )
        return
    fi
    local base; base="$(basename "$SRC")"
    # shellcheck disable=SC2086
    # $CMD is deliberately unquoted: it may carry several arguments
    # (CMD="--selftest --verbose") and must word-split.
    ( cd "$WORK" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        python3 "$base" $CMD 2>&1 )
}

mutation_baseline () {
    _mut_stage
    local out rc basefail
    out="$(_mut_run)"; rc=$?
    MUT_BASE_PASS="$(printf '%s\n' "$out" | grep -c '\[PASS\]')"
    basefail="$(printf '%s\n' "$out" | grep -c '\[FAIL\]')"
    if [ "$rc" -ne 0 ] || [ "$basefail" -ne 0 ] || [ "$MUT_BASE_PASS" -eq 0 ]; then
        echo "BASELINE IS NOT CLEAN — $MUT_BASE_PASS passed, $basefail failed, exit $rc."
        echo "Fix the suite before mutating it. Every verdict below would be meaningless."
        MUT_BASE_PASS=""
        return 1
    fi
    echo "baseline: $MUT_BASE_PASS assertions pass, 0 fail"
    return 0
}

run_mutant () {
    local name="$1" old="$2" new="$3"
    local helper
    helper="$(_mut_helper)" || { MUT_NONRESULTS=$((MUT_NONRESULTS+1)); return 1; }

    if [ -z "$MUT_BASE_PASS" ]; then
        mutation_baseline || { MUT_NONRESULTS=$((MUT_NONRESULTS+1)); return 1; }
    fi

    _mut_stage
    local target; target="$(_mut_target)"
    [ -f "$target" ] || {
        printf '  %-44s NO SUCH FILE IN THE STAGED COPY — not a result\n' "$name"
        MUT_NONRESULTS=$((MUT_NONRESULTS+1)); return 1
    }
    cp "$target" "$WORK/.orig"

    if ! python3 "$helper" "$target" "$old" "$new"; then
        printf '  %-44s ANCHOR FAILED — not a result\n' "$name"
        MUT_NONRESULTS=$((MUT_NONRESULTS+1)); return 1
    fi

    # Prove the file actually changed. The old check grepped for the
    # replacement text, which matches everything when the replacement is empty
    # — so deletion mutants were verified by a check that could not fail.
    # Comparing against the untouched copy works for every case.
    if cmp -s "$WORK/.orig" "$target"; then
        printf '  %-44s NOT APPLIED — not a result\n' "$name"
        MUT_NONRESULTS=$((MUT_NONRESULTS+1)); return 1
    fi
    rm -f "$WORK/.orig"

    local out rc pass_n fail_n
    out="$(_mut_run)"; rc=$?
    pass_n="$(printf '%s\n' "$out" | grep -c '\[PASS\]')"
    fail_n="$(printf '%s\n' "$out" | grep -c '\[FAIL\]')"

    # A crash is not a catch. The suite never reached the assertion, so the
    # run says nothing at all about whether the assertion works.
    if [ "$fail_n" -eq 0 ] && [ "$pass_n" -eq 0 ]; then
        printf '  %-44s CRASHED — not a result\n' "$name"
        printf '      %s\n' "$(printf '%s\n' "$out" | tail -1)"
        MUT_NONRESULTS=$((MUT_NONRESULTS+1)); return 1
    fi

    if [ "$fail_n" -gt 0 ]; then
        printf '  %-44s CAUGHT (%s failed)\n' "$name" "$fail_n"
        MUT_CAUGHT=$((MUT_CAUGHT+1)); return 0
    fi

    if [ "$pass_n" -lt "$MUT_BASE_PASS" ]; then
        printf '  %-44s SHORTER SUITE (%s of %s ran) — not a result\n' \
               "$name" "$pass_n" "$MUT_BASE_PASS"
        MUT_NONRESULTS=$((MUT_NONRESULTS+1)); return 1
    fi

    printf '  %-44s ** SURVIVED ** (%s passed, exit %s)\n' "$name" "$pass_n" "$rc"
    MUT_SURVIVORS=$((MUT_SURVIVORS+1)); return 2
}

mutation_summary () {
    echo
    echo "  caught $MUT_CAUGHT   survived $MUT_SURVIVORS   not-a-result $MUT_NONRESULTS"
    if [ "$MUT_SURVIVORS" -gt 0 ]; then
        echo "  A SURVIVOR MEANS AN ASSERTION IS NOT DOING ITS JOB."
        return 1
    fi
    if [ "$MUT_NONRESULTS" -gt 0 ]; then
        echo "  Non-results tell you nothing. Fix the mutation and run it again."
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# MUTATE THE CODE, NOT THE TEST.
#
# Deleting a clause from an assertion tests whether that clause is redundant,
# which is a different and much less interesting question. What you want to
# know is whether a realistic FAULT is caught: an off-by-one, a wrong constant,
# a forgotten join, a reversed comparison, a dropped branch, a value that stops
# being clamped.
# ---------------------------------------------------------------------------
