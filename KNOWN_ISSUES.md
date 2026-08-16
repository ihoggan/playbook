# Known issues — playbook

Open problems, each shipped with its diagnosis, so the next person starts from
the answer rather than the symptom.

As of the commit that added `HANDOFF.md`. Selftest **38/38**.

---

## #1 — `ADOPT_EXISTING.md` has been rehearsed, not used

**Reduced, still open.** The document was driven end to end against a
deliberately messy synthetic project — two files, no tests, no CI, generated
data, unsorted imports. That found four faults, all now fixed:

1. **The dependency one-liner was wrong.** It read `n.names[0]` only, so
   `import sys, json, os` reported `sys` and silently dropped the other two.
   Plausible, wrong output is the worst kind. It also scanned a single file.
2. **No `.gitignore` arrived**, so the venv the document tells you to create
   landed in `git status` at the exact step that says *commit that state
   untouched*.
3. **The CI workflow hardcoded `main.py` four times.** An adopted project's
   entry point is called something else, and nothing said to change it. Now
   one `ENTRY:` line.
4. **The lint job fails on adoption and the document did not warn.** Existing
   code has never seen `isort`. Now covered, with the fix positioned *after*
   the baseline so it doubles as a rehearsal.

What is still untested is a **real** project — one with dependencies,
non-determinism, and history. A synthetic fixture cannot supply those, and
building one elaborate enough to try would be testing my imagination rather
than the document.

*Closes when a real project goes through it,* and whatever that finds comes
back here.

## #3 — `--files-only` does not tell you what it skipped

Adoption skips every `new-only` manifest entry so it cannot overwrite the
project being adopted, and skips `keep-existing` entries you already have.
Correct, but silent: someone who *wanted* the spine's `main.py` as a reference
gets no hint that one exists.

*Fix when it comes up:* print the skipped entries as a closing note. Small, but
it needs an assertion or it will drift out of step with the manifest.

## #2 — the `chmod +x` in the scaffolder looks redundant and is not

`cp` preserves the source file's mode, and the tools are tracked at `100755`,
so a scaffolded project gets an executable harness whether or not
`new-project.sh` runs `chmod`. Mutating that line away therefore **survives**
the suite — it is testing redundancy, not detection, which section 4 warns is
a different and much less interesting question.

Keep the line. It is load-bearing on the delivery route actually in use:
Python's `zipfile` does not restore permission bits on extract, so a repo
updated from a delivered archive can carry non-executable tools, and then `cp`
propagates that into every project scaffolded from it. Assertion 7 now checks
the repo's own tools directly, which is where the fault would actually land.

---

## Closed

**Four defects found at one commit old**, all fixed — four drifted copies of
the copy-in list (one broken), CI that could not be green on the first push, a
mutation harness that printed a number instead of a verdict, and
`${BASH_SOURCE[0]}` under zsh. See `CHANGELOG.md`.

**#2, the baseline re-pin, is closed.** It could not be enforced — no check
can tell a deliberate baseline from a forgotten one — so the scaffolder now
writes it into the new project's own `KNOWN_ISSUES.md` as its issue #1, with
the command to run. Carried rather than remembered, which is the mechanism this
file *is*. Assertion 15 checks it arrives.

**#4, zsh, is closed.** `mutate.sh` is now sourced and run under a real zsh by
assertion 44, CI installs zsh and parses every script under both shells, and
finding the helper no longer depends on `BASH_SOURCE` alone. Doing it properly
also exposed an over-correction: dropping `BASH_SOURCE` for a plain search had
removed the most reliable location of all — the directory `mutate.sh` is in —
so sourcing it from any other working directory failed in **both** shells.
Assertion 43 covers that, behaviourally.

**The scaffolder assumed `~/playbook`** and refused to run in CI, where the
checkout lives under the runner's workspace. Fixed at `f5589a8` by deriving the
path from the script's own location. The reason nothing caught it — the test
fixture set `$PLAYBOOK` on every call, so the default was never exercised — is
now `PLAYBOOK.md` section 4.
