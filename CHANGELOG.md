# Changelog

What changed and **why** — including the fixes that were wrong first, and what
the wrong one taught.

---

## Unreleased — the framework gets a selftest

The playbook demanded a selftest that counts, a smoke test, a hashable
baseline and CI that pins the numbers, from every project it touched. It had
none of them. Four real defects were sitting in it at one commit old, three of
them in the tools it hands out.

### The four

1. **The copy-in list lived in four places and had already drifted.** The
   script copied `MAKERS_INSTRUCTIONS.md` into a new project; the by-hand
   route in that same document did not, while claiming both routes produced
   the same result. `README.md`'s copy was outright wrong — it copied
   `mutate.sh` without `_mutate_apply.py`, which it cannot run without, so
   anyone following the README got a harness that reported `ANCHOR FAILED` for
   every mutant. This is section 8 of the playbook, in the playbook.

   *Fix:* `SCAFFOLD_MANIFEST` is now the only place the list lives. The
   by-hand route is `--dry-run`, printing the commands the script would run.
   Adoption is `--files-only`, which copies into an existing directory and
   overwrites nothing.

2. **CI could not be green on the first push**, which three documents promised
   it would be. The scaffolded workflow ran `py_compile main.py` against a
   repo with no `main.py`, so a brand-new portfolio repo opened with a red X.
   `SELFTEST_COUNT: 0` was also a *passing* value.

   *Fix:* the scaffold ships a working spine — `main.py` with `--selftest`,
   `--smoke` and `--snap` — and the scaffolder pins `SELFTEST_COUNT` and
   `BASELINE_MD5` by **running** it. Numbers from a real run, never guessed.

3. **The mutation harness printed a number to interpret, not a verdict.** A
   caught mutant read `0 passed` and a survivor read `3 passed` — the same
   shape, told apart by a count you had to remember. Its "belt and braces"
   check grepped for the replacement text, which matches everything when the
   replacement is empty, so deletion mutants were verified by a check that
   could not fail. And a crashing mutant looked like a catch.

   *Fix:* CAUGHT / SURVIVED / CRASHED / ANCHOR FAILED / NOT APPLIED / SHORTER
   SUITE, a clean baseline run first so the harness knows the expected count
   itself, verification by comparison against the untouched copy, and
   `mutation_summary` exiting non-zero on a survivor.

4. **`mutate.sh` located its helper with `${BASH_SOURCE[0]}`**, which zsh does
   not define — the shell actually in use. Sourcing it from zsh left the path
   empty and every mutant reported `ANCHOR FAILED`: a message blaming the
   anchor for a path problem.

   *Fix:* a search across `$MUT_HELPER`, `./tools/`, `./` and
   `~/playbook/tools/`, with an error that says what it looked for.

### The fixes that were wrong first

- **Lucky data, then lucky vocabulary.** The assertion for "refuses without a
  manifest" pointed at an empty playbook directory — which trips the
  `PLAYBOOK.md` guard first, so gutting the manifest guard survived. The fix
  gave it a valid playbook missing only the manifest, and checked the output
  named `SCAFFOLD_MANIFEST`. That survived too: the gutted version's `grep`
  error names the same file. It now asserts the guard's **effect** — refusing
  before anything is created.

- **A guard placed after the thing it guards against.** The scaffolder checks
  whether the spine's selftest failed, but ran under `set -euo pipefail`, so a
  failing selftest killed the script on the line that *measured* it, one line
  before the check that would have reported it. Written, read over, and
  unreachable. Now the selftest is captured once into a variable with its exit
  status taken out of the shell's hands.

- **Configuration by environment variable, used recursively.** Adding
  `TREE`/`RUN` to the harness so it could mutate a whole repo meant the
  framework's own selftest — which drives the harness — inherited them and
  quietly tested the wrong tree.

- **Two absence assertions fired on the comments explaining the ban.** "Never
  `git add -A`" and "does not use `BASH_SOURCE`" both tripped on prose
  describing the banned thing. A false alarm is how an assertion earns the
  right to be ignored; they now look at code, not comments.

### Also

- `tools/selftest.py` — 37 assertions, driving the real scaffolder and the
  real harness rather than inspecting their source. `.github/workflows/validate.yml`
  pins the count.
- Scaffolded projects get a rendered `README.md` and MIT `LICENSE`, so a new
  repo's landing page is not blank.
- The spine's smoke test reports iterations **completed**, not requested; the
  report was split into a pure `smoke_line()` because the difference is
  invisible from outside when the loop is healthy.
- CI now compiles and lints *every* tracked script via `git ls-files`, not
  just `main.py`.
- `PLAYBOOK.md` gains section 12 and six new failure modes in section 4.

Validation: selftest **37/37**, 0 failed. Mutation sweep **25 mutants, 25
caught, 0 survived, 0 non-results**. pyflakes 0, isort clean, shellcheck
clean, `bash -n` clean on both scripts. Scaffolded project verified end to
end: 7 assertions, smoke 90 of 90, baseline
`135e2fc4ac5bb293582e750fc7f1c0e0`, harness catching a real mutant out of the
box.

---
