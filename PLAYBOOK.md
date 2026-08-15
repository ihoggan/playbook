# Playbook

Distilled from HUSTLER (r6 → r70). Everything here earned its place by
catching something real. Nothing is language-specific.

Drop this in a new repo, adjust the specifics, and start from here rather
than rediscovering it.

---

## 1. The agreement

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

## 2. The validation chain

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

## 3. Assertions, and mutation testing

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
  present in the file before running.**

---

## 4. CI that enforces numbers

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

---

## 5. Verify from a fresh clone

After a push, **clone into a new directory and run the chain there** — do not
trust the terminal you have been working in. It catches uncommitted files,
files that were never added, and line-ending damage.

A fresh clone should be *clean*. Anything showing as modified straight after
checkout is a real problem.

---

## 6. Reproduce the fault locally before asking anyone to test

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

## 7. Fix the class, not the instance

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

## 8. Documents that explain WHY

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

## 9. Delivery mechanics

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

## 10. What did not work

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
