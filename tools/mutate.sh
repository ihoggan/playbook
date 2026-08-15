#!/usr/bin/env bash
#
# mutate.sh — mutation-test helper.
#
# An assertion that cannot fail is not an assertion. The only way to know is to
# break the code deliberately and check that the assertion notices.
#
# THE POINT OF THIS SCRIPT IS THE ANCHOR CHECK. A mutation whose search text
# does not match writes nothing, the suite then passes, and the result is
# indistinguishable from "the assertion caught it" — so a pass gets recorded
# that never happened. That has actually occurred on a real project. Every path
# below either applies the mutation AND verifies it is present in the file, or
# fails loudly and returns nothing you could mistake for a result.
#
# Usage:
#     export SRC=main.py CMD=--selftest
#     source tools/mutate.sh
#     run_mutant "off-by-one in the seeding" "range(n)" "range(n - 1)"
#
# A healthy assertion reports FAILURE(S) for that mutant.
# A mutant reported as PASSING means the assertion is not doing its job —
# usually because it is circular, asserts an inequality where the contract is
# exact, or was written against data that cannot reach the branch.

SRC="${SRC:-main.py}"           # file under test
WORK="${WORK:-/tmp/mutwork}"    # scratch dir the mutated copy runs in
CMD="${CMD:---selftest}"        # how to run the suite
MUT_HELPER="${MUT_HELPER:-$(dirname "${BASH_SOURCE[0]}")/_mutate_apply.py}"

run_mutant () {
    local name="$1" old="$2" new="$3"
    local base
    base="$(basename "$SRC")"

    rm -rf "$WORK" && mkdir -p "$WORK"
    cp "$SRC" "$WORK/$base"
    # Bring along sibling modules the file imports.
    for f in "$(dirname "$SRC")"/*.py; do
        [ "$(basename "$f")" = "$base" ] || cp "$f" "$WORK/" 2>/dev/null
    done

    if ! python3 "$MUT_HELPER" "$WORK/$base" "$old" "$new"; then
        echo "[$name] ANCHOR FAILED — NOT A RESULT"
        return 1
    fi

    # Belt and braces: prove the change really is in the file before trusting
    # any result produced by running it.
    if ! grep -qF -- "$new" "$WORK/$base"; then
        echo "[$name] MUTATION NOT PRESENT AFTER WRITE — NOT A RESULT"
        return 1
    fi

    local out
    out="$( cd "$WORK" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
            python3 "$base" $CMD 2>&1 | tail -1 )"
    echo "[$name] applied+verified -> $out"
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
