# Known issues — playbook

Open problems, each shipped with its diagnosis, so the next person starts from
the answer rather than the symptom.

As of the commit that added `HANDOFF.md`. Selftest **38/38**.

---

## #1 — `ADOPT_EXISTING.md` is the least-tested path

`tools/selftest.py` covers `--files-only` mechanically: it copies the right
files, overwrites nothing, and creates no repo or venv. What has **never**
happened is a real half-finished project being taken through the whole
sequence — baseline, first assertion, CI numbers, first green run.

The document is therefore written from reasoning rather than from experience,
which is precisely the standard `PLAYBOOK.md` warns against everywhere else.

*Not a bug yet.* It becomes one the first time it is used and something in it
turns out to be wrong. Whatever that is belongs back in the repo.

## #2 — the spine's baseline hash is only meaningful until you replace it

`templates/main.py` ships a deterministic LCG so `--snap` has something real to
hash, and the scaffolder pins that hash into CI. The moment the demo core is
replaced with a real project, `BASELINE_MD5` is pinning **the demo's** output,
not yours — so it stays green while checking nothing that matters.

`MAKERS_INSTRUCTIONS.md` says to re-pin it. Nothing enforces it, and nothing
can: no assertion can tell a deliberate baseline from a forgotten one.

*Mitigation if it bites:* have the spine's snap write a marker line naming the
template, and have CI warn while that marker is still present. Not built —
a warning that cannot fail the build is decoration by section 5, so it would
need thinking through rather than adding.

## #3 — `--files-only` does not tell you what it skipped

Adoption skips every `new-only` manifest entry so it cannot overwrite the
project being adopted. That is correct, but silent: a user who *wanted* the
spine's `main.py` as a reference gets no hint that one exists.

*Fix when it comes up:* print the skipped entries as a closing note. Small, but
it needs an assertion or it will drift out of step with the manifest.

## #4 — CI reruns are the only proof for anything platform-specific

`tools/selftest.py` runs in one place at a time. The zsh fault in the mutation
harness — `${BASH_SOURCE[0]}`, which zsh does not define — was found by reading
the shell in use, not by any test, and assertion 38 only pins that the string
is absent from the code. Nothing here actually **executes** anything under zsh,
because the runner is bash.

*Consequence:* a second bash-only construct could be added and no assertion
would notice. `${BASH_SOURCE}` is guarded by name; nothing else is.

*Fix when it matters:* a `shell: zsh` matrix leg that sources `mutate.sh` and
runs one mutant. Cheap, and it would convert a name-check into a behaviour
check.

## #5 — the `chmod +x` in the scaffolder looks redundant and is not

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

**The scaffolder assumed `~/playbook`** and refused to run in CI, where the
checkout lives under the runner's workspace. Fixed at `f5589a8` by deriving the
path from the script's own location. The reason nothing caught it — the test
fixture set `$PLAYBOOK` on every call, so the default was never exercised — is
now `PLAYBOOK.md` section 4.
