# Handoff — playbook

**Status:** selftest **44/44**, 0 failed. CI green on `main`. Last mutation
sweep: **26 mutants, 26 caught, 0 survived, 0 non-results**, plus direct
proofs for the assertions text mutation cannot reach.

Read `PLAYBOOK.md` for the practices themselves. This file is for someone
about to change *this repo* — what is load-bearing, and what has already been
decided and should not be relitigated without a reason.

---

## What this repo is

Two things in one place:

1. **The practices** — `PLAYBOOK.md`, plus `MAKERS_INSTRUCTIONS.md` (starting
   fresh) and `ADOPT_EXISTING.md` (retrofitting).
2. **The tools that apply them** — a scaffolder, a mutation harness, CI and
   document templates, and a selftest that holds the whole thing to its own
   standard.

The second exists because the first was being followed by hand, and by hand it
drifted. Four defects were sitting in this repo at one commit old.

## Architecture — the parts that are load-bearing

**`SCAFFOLD_MANIFEST` is the single source of truth for what a project gets.**
Nothing else may list those files. `tools/new-project.sh` reads it, the
by-hand route is `--dry-run` (which prints what the script would run), and
adoption is `--files-only`. The documents describe the *commands*, never the
file list. Assertion 6 fails if a `cp ... playbook ...` line reappears in any
document — that is deliberate, and it is an absence assertion because a rival
copy is exactly the thing nobody notices adding.

**The scaffolder pins CI's numbers by running the spine, never by guessing.**
`SELFTEST_COUNT` and `BASELINE_MD5` come out of an actual `--selftest` and
`--snap`, which is what makes "green on the first push" true rather than
aspirational. If the spine fails, the scaffolder refuses rather than pinning
the numbers of a broken run.

**`tools/mutate.sh` reports a VERDICT, not a number.** CAUGHT, SURVIVED,
CRASHED, ANCHOR FAILED, NOT APPLIED, SHORTER SUITE. Only the first two are
results at all. `mutation_summary` exits non-zero on a survivor, so a sweep can
fail a script. It takes a clean baseline first so it knows the expected
assertion count itself rather than relying on the reader to remember it.

**`tools/selftest.py` drives the real tools, not their source text.** It
scaffolds into temp directories, runs the harness against two fixtures that
differ only in whether their assertion is honest, and asserts the verdicts come
out different. Source-text clauses are used only where behaviour cannot be
reached purely.

## Standing decisions — do not undo without a reason

- **`new-project.sh` does not create or push to a GitHub repo.** That stays
  manual so a script can never put something in the wrong place.
- **It refuses a directory that already exists.** `--files-only` is the way
  into an existing project, and `new-only` entries in the manifest are skipped
  there so adoption cannot overwrite the work being adopted.
- **`PLAYBOOK` is derived from the script's own location**, not `$HOME/playbook`,
  with the environment variable still overriding. Assuming `~/playbook` is what
  broke CI at `70e6677`.
- **The mutation harness is configured by environment variables**, which means
  any caller that is itself being driven by the harness must set *every*
  variable it reads, including the ones it wants empty (`TREE=`, `RUN=`). See
  `run_harness` in `tools/selftest.py`.
- **The manifest has three flags:** `render` (substitute `__NAME__`,
  `__YEAR__`, `__HOLDER__`), `new-only` (skipped by `--files-only`, because it
  would overwrite the work being adopted) and `keep-existing` (copied only when
  the destination is absent). Adding a fourth means updating `KNOWN_FLAGS` in
  `tools/selftest.py`, which asserts no flag is a typo.
- **CI names its entry point once**, as `ENTRY:` at the top of
  `templates/validate.yml`. Four hardcoded copies of `main.py` was four places
  an adopter had to notice.
- **`--no-venv` exists for CI and for adoption**, not as a convenience. The
  venv-first rule in `PLAYBOOK.md` section 1 still applies to real work.
- **`shellcheck disable=SC2086` on `$CMD` in `mutate.sh` is deliberate** — it
  may carry several arguments and must word-split. The comment says so; do not
  quote it.

## Changing things safely

Every change runs the chain and reports the numbers, never "passed":

```bash
python3 tools/selftest.py                  # expect: 44 assertions, 0 failed
bash -n tools/*.sh && zsh -n tools/*.sh
python -m pyflakes $(git ls-files '*.py')
python -m isort --check-only $(git ls-files '*.py')
shellcheck $(git ls-files '*.sh')
```

Adding an assertion means bumping `SELFTEST_COUNT` in
`.github/workflows/validate.yml` in the **same commit**. Adding one to the
spine (`templates/main.py`) also means bumping `SELFTEST_COUNT` in
`templates/validate.yml` — assertion 17 catches that drift, on purpose.

To mutation-test the framework itself, the harness needs whole-tree mode:

```bash
export TREE=. WORK=/tmp/fwmut RUN="python3 tools/selftest.py"
export MUT_HELPER="$PWD/tools/_mutate_apply.py"
. tools/mutate.sh
SRC=tools/new-project.sh
mutation_baseline
run_mutant "existing-dir guard removed" 'if [ -e "$DEST" ] && [ "$DRY" -eq 0 ]; then' 'if false; then'
mutation_summary
```

`SRC` can be reassigned between mutants to move to another file.

## Pushing

All commits come from Linux. Windows machines download, build and test; they do
not push. Git for Windows defaults to `core.autocrlf=true` and committing from
there reintroduces the whole-file-modified phantom.

Verify from a **fresh clone** after pushing, not from the working directory:

```bash
cd /tmp && rm -rf pbverify && git clone <url> pbverify && cd pbverify \
  && git status --porcelain && echo "(empty = clean)" \
  && python3 tools/selftest.py | tail -1
```

---

**Open work:** see `KNOWN_ISSUES.md`.
