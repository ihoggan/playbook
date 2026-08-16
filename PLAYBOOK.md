# Playbook

Distilled from HUSTLER (r6 → r70). Everything here earned its place by
catching something real. Nothing is language-specific.

Drop this in a new repo, adjust the specifics, and start from here rather
than rediscovering it.

---

## 1. The environment

Before any library is installed, on every machine, every project:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

**A venv, always.** Not because a project needs isolation on day one, but
because the day it does need it is the day you have already polluted the
system Python and cannot tell what the project actually depends on. Debian,
Ubuntu and Raspberry Pi OS now enforce this anyway (PEP 668) and will refuse a
bare `pip install` — treat that as the correct default rather than an obstacle
to work around with `--break-system-packages`.

**Upgrade pip before installing anything.** A stale pip resolves differently,
and on ARM or a new Python version it will fall back to building a package
from source where a prebuilt wheel exists — the difference between four
seconds and twenty minutes, or between a clean install and a missing
compiler.

**Pin the versions.** `requirements.txt` carries exact versions, and adding to
it is a deliberate decision, not a convenience. Write that intent in the file
itself:

```
# Dependencies — these, and nothing else.
# Adding to this file needs an explicit decision.
pygame==2.6.1
pymunk==7.3.0
```

Keep the dependency list as short as the project can bear. A project with two
dependencies and no asset files is one that packages, ports and reproduces
easily — and that pays off in places you cannot predict at the start.

**`.venv/` goes in `.gitignore`.** Never committed, always reproducible from
`requirements.txt`. If it cannot be rebuilt from that file alone, the file is
wrong.

CI does exactly the same thing — same pip upgrade, same pinned install — so
what breaks locally breaks there too, rather than only in front of a user.

---

## 2. The agreement

**Decision → sign-off → build → validate.**

Anything with a genuine fork gets a written brief BEFORE any code: the
options laid out, a recommended default, and an explicit ask for sign-off.
Small fully-specified requests can go straight to build.

This rule mostly works by *stopping the assistant*. Its value is the briefs
that got rejected — the feature that was already built, the roadmap item that
lost to what the human actually plays.

**Report the actual numbers, never "passed".** "The tests pass" hides a
truncated test file. "127 assertions, 0 failures" does not.

**Ask, don't assume.** When a generic noun has a real spec behind it, ask
which one and to what spec. When the roadmap and the human's actual usage
disagree, put it to them — do not resolve it silently in favour of the
roadmap.

---

## 3. The validation chain

Every change runs the same chain, and the numbers get reported:

| Step | What it catches |
|---|---|
| compile / syntax check | the obvious |
| **selftest** (assertion count + failures) | logic regressions |
| **batch run** (headless, N iterations) | behavioural drift |
| **smoke test** (render/execute N frames, exit code) | "it starts" |
| **snapshot hash** (md5 of rendered output) | *unintended* visual change |
| linters (blocking, not advisory) | rot |

**The snapshot baseline is the quiet hero.** A hash of the rendered output,
recorded once and checked on every change. It stayed byte-identical across
thirty revisions of refactoring — which is what made those refactors
trustworthy. Re-capture it only with explicit sign-off, and say so in the
commit message.

The same idea generalises: hash any deterministic output. A fixed-seed run
that is byte-reproducible is how you prove an optimisation changed nothing.

---

## 4. Assertions, and mutation testing

**One new assertion per feature**, on the pure testable core — not the
framework-dependent wrapper.

**Then mutate the code and confirm the assertion fails.** An assertion that
cannot fail is not an assertion. This is the single highest-value practice in
this document, because every failure mode below was found by it and none
would have been found without it.

The failure modes, all observed:

- **Circular assertions.** Checking a function's output against the same
  function's own logic. A seeding routine was compared to its own output, so a
  mutant that seeded *alphabetically* passed.
- **Lucky data.** A severity-ordering clause could never fail because none of
  the real input strings could trigger both branches. Check the *actual
  vocabulary* the system produces before asserting an ordering matters.
- **Inequalities where the contract is exact.** "The label stays inside the
  box" passed both a frozen offset and a zero pad. Pin the exact position.
- **Asserting source text instead of behaviour.** A clause checking that a
  call *appears in the source* passed while a mutant gutted the function it
  called. Make it pure and assert what it returns.
- **Asserting a helper, not its callers.** A pure helper was tested in
  isolation and passed for two releases while no code path actually called it
  in half the cases. Assert what the caller consumes.
- **Clause-removal "mutants".** Deleting an assertion clause tests
  redundancy, not detection. Mutate the *code*, not the test.
- **Mutations that never applied.** A failed anchor match writes nothing and
  prints a clean-looking result indistinguishable from "caught". **Hard-fail
  the mutation helper when the anchor does not match, and verify the change is
  present in the file before running.** Verify by comparing against the
  untouched copy, not by searching for the replacement text — searching for an
  *empty* replacement matches everything, so deletion mutants were being
  "verified" by a check that could not fail.
- **A crash is not a catch.** A mutant that stops the module importing means
  the suite never reached the assertion, so the run says nothing about whether
  the assertion works. Report it as its own verdict.
- **Lucky vocabulary, one layer under lucky data.** A guard was tested by
  checking the output contained the name of the file it guards. Deleting the
  guard *survived*: the resulting `grep` error names the same file. Assert the
  guard's **effect** — that it refuses before creating anything — not its
  wording.
- **Something invisible from outside needs a pure function and an impossible
  case.** A smoke test that printed the iteration count it was *asked* for
  rather than the count it *completed* cannot be caught end to end, because in
  a healthy run the two numbers are equal. Split the report into a pure
  function and hand it a case a working run cannot produce.
- **A verdict beats a number.** The harness used to print the last line of the
  mutated run. A catch read `0 passed` and a survivor read `3 passed` — the
  same shape, told apart by a count you had to remember. A result you can
  misread is barely better than a result that never happened, so the harness
  now says CAUGHT or SURVIVED and exits non-zero on a survivor.

---

## 5. CI that enforces numbers

Exit codes are not enough. A truncated file whose remaining tests all pass
exits 0 and turns the badge green — this actually happened.

So CI pins the **counts** as environment variables:

```yaml
env:
  SELFTEST_COUNT: 129
  SNAP_MD5: 62c87ddb6d1f0ee36f36a71a5000cd5f
```

and fails if they do not match. Bumping them is deliberate, in the same
commit, mentioned in the message. The upkeep *is* the point.

No `continue-on-error`. A check that cannot fail the build is decoration.

Run CI on the feature branch too, not just the trunk.

**Green on the first push, or say why not.** A workflow that is red from day
one teaches you to ignore it, and by the twentieth commit the red X means
nothing. The way to keep that promise is not to soften the check but to ship
something honest for it to check: a scaffold that arrives with a working
selftest, smoke test and hashable baseline, with the counts filled in **by
running it**. Numbers pinned from a real run, never guessed.

---

## 6. Verify from a fresh clone

After a push, **clone into a new directory and run the chain there** — do not
trust the terminal you have been working in. It catches uncommitted files,
files that were never added, and line-ending damage.

A fresh clone should be *clean*. Anything showing as modified straight after
checkout is a real problem.

---

## 7. Reproduce the fault locally before asking anyone to test

The most expensive mistake in this project: a packaging bug was guessed at
across three rounds on a second machine, with the human typing error text out
by hand. The same logic ran locally. Reproducing it took ten minutes and gave
the answer immediately.

**If a fix does not work, stop and measure. Do not guess again.** Guessing
twice is the signal to build a reproduction.

Corollary: the human has the eyes, ears and hardware. Spend their attention on
what only they can judge — how it looks, how it sounds, how it feels — not on
executing experiments that could have been run automatically.

---

## 8. Fix the class, not the instance

A test compared file paths against literals with forward slashes. It failed on
Windows. It was fixed — in the one place that had failed. The identical fault
in another test was found later by the human, on his own machine.

When you learn *why* something broke, sweep for that shape everywhere before
moving on.

Related: **if state is computed in more than one place, it will drift.** One
rule was written out five times; fixing four of five would have left the fifth
silently wrong. The cure is structural — one function, every caller using it —
not a fifth careful copy.

---

## 9. Documents that explain WHY

The repo carries the memory between sessions. What survives is *reasoning*,
not status.

- **CHANGELOG** — what changed and, crucially, *why*, including the fixes that
  were wrong first and what the wrong one taught.
- **KNOWN_ISSUES** — open problems shipped with their diagnoses, so the next
  person starts from the answer rather than the symptom.
- **HANDOFF** — current state, architecture doctrine, the standing exceptions
  that must not be "tidied away".
- **CONTRIBUTING** — the baseline a newcomer runs, and the war stories behind
  each rule.

Every release, sweep the docs for stale version and count claims — they go
stale silently and nothing checks them.

**Distinguish live claims from historical record.** A quoted past snapshot
with old hashes is a *record*; "correcting" it destroys what it exists to
preserve.

---

## 10. Delivery mechanics

For handing files between environments:

- One archive, checksums published alongside, verified before anything is
  copied into the repo.
- **Chain the checksum guard and the copy in a single command block.** An
  unchained guard prints a failure it cannot stop, and the wrong file gets
  committed. Split across two messages once, and an entire release sat
  unnoticed in a download folder while git reported nothing to commit.
- **Never `git add -A`.** Name every file. A sweep once pulled in build cruft.
- Check `git branch --show-current` before copying anything in.

---

## 11. What did not work

Worth recording so it is not repeated:

- **Chasing a rendering problem with geometry tools.** Something looked wrong,
  and the geometry was adjusted for four rounds. The geometry was correct; the
  *depth cue* was missing. Identify which layer the complaint is really about.
- **Optimising the wrong population.** Measuring, but on a filtered set — and
  the filter was triggered by failure, which flattered every number.
- **Front-loading a plan onto a passing idea.** A platform was mentioned in
  passing and got a full measurement plan in reply, which made a three-command
  job look heavy enough to abandon. Match the weight of the answer to the
  weight of the question.
- **A guard placed after the thing it guards against.** A script checked
  whether its selftest had failed — but ran under `set -euo pipefail`, so the
  failing selftest killed the script on the line that *measured* it, one line
  before the check that would have reported it. The guard was written, tested
  by eye, and unreachable. When you deliberately run something that is allowed
  to fail, take its failure out of the shell's hands first.
- **A fixture that supplies the value under test.** A script defaulted its
  config path to `$HOME/playbook`; every test set that variable explicitly, so
  the default was never once exercised and the script could not run from a
  clone anywhere else. CI found it immediately. If a default matters, test with
  it absent — and with the fallback it would use made invalid.
- **Configuration by environment variable, used recursively.** A test harness
  configured through exported variables was used to test a suite that itself
  drove the same harness. The inner one inherited the outer one's settings and
  quietly tested the wrong thing. Set every variable the tool reads, including
  the ones you want empty.

---

## 12. Hold the practices themselves to the practices

This document asked every project for a selftest that counts, a smoke test, a
hashable baseline and CI that pins the numbers. The repo carrying it had none
of them, and four real defects were sitting in it at one commit old — three in
the tools it hands out:

- the copy-in list lived in four places and had **already drifted**, and one
  copy was wrong in a way that broke the mutation harness for anyone who
  followed it
- the scaffolded CI could not be green on the first push, which three
  documents promised it would be
- the harness printed a number to interpret rather than a verdict
- it located its helper with `${BASH_SOURCE[0]}`, which zsh does not define —
  the shell actually in use

None of those were found by reading. They were found by `tools/selftest.py`
running the real scaffolder and the real harness, and then by mutating both.
Tooling is code, and code that is not tested is code you are trusting because
it looks right.
