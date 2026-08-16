# playbook

How I run projects, and the reusable pieces that go with it.

## Start here

```bash
git clone https://github.com/ihoggan/playbook.git ~/playbook
~/playbook/tools/new-project.sh myproject
cd ~/myproject && python main.py --selftest
```

Thirty seconds later you have a repo with a passing test suite, a smoke test, a
hashable baseline, CI already pinned to those real numbers, a README, a licence
and a mutation harness. Push it and the workflow is green on the **first**
commit.

Run it with no arguments and it asks instead:

```bash
~/playbook/tools/new-project.sh
```

For a project that already exists:

```bash
~/playbook/tools/new-project.sh --files-only ~/oldproject   # overwrites nothing
```

To see every command it would run, without running any of them:

```bash
~/playbook/tools/new-project.sh --dry-run myproject
```

That is the whole thing. Everything below is why.

---

## Why bother

The setup that gets skipped on day one is the setup that costs most to add on
day four hundred. A selftest that reports a **count**, a deterministic baseline
that can be hashed, CI that fails on a wrong number rather than a wrong exit
code — nobody builds those first, because on day one there is nothing to test.
By the time there is, adding them means touching code you can no longer prove
you did not break.

This makes that the starting position instead of the aspiration.

What it does **not** do is write the project. It gives you a spine and a
discipline; the value is that whatever you build inside it can be changed
safely later.

Distilled from HUSTLER — a UK blackball pool physics sandbox that ran to
seventy revisions. Every practice here earned its place by catching something
real, and the failures in `PLAYBOOK.md` section 11 are as useful as the
successes.

## What's here

| File | What it is |
|---|---|
| `PLAYBOOK.md` | The practices themselves. Read this first. |
| `MAKERS_INSTRUCTIONS.md` | **Step by step, start to finish.** Start here. |
| `ADOPT_EXISTING.md` | Bringing an existing project up to standard. |
| `templates/validate.yml` | CI that enforces **counts**, not just exit codes. |
| `templates/CONTRIBUTING.md` | Skeleton for a new repo's contributor guide. |
| `SCAFFOLD_MANIFEST` | **The one place** that says what a project gets. |
| `templates/main.py` | The spine: `--selftest`, `--smoke`, `--snap`, day one. |
| `templates/README.md`, `templates/LICENSE` | So a new repo is not blank. |
| `tools/mutate.sh` | Mutation harness. Gives a **verdict**, not a number. |
| `tools/new-project.sh` | Scaffolds a project. `--dry-run`, `--files-only`. |
| `tools/selftest.py` | The playbook checking itself. |
| `HANDOFF.md` | Where this repo is up to, and its standing decisions. |
| `KNOWN_ISSUES.md` | Open problems, each with its diagnosis. |
| `CHANGELOG.md` | What changed and why, including what was wrong first. |

## Carrying it between projects

The scaffold puts the practices *inside* the new repo, so the first message of
any session is:

> New project. Read `PLAYBOOK.md` and `MAKERS_INSTRUCTIONS.md` in the repo
> first — that's how we work. Then read `HANDOFF.md` for where the project is
> up to.

That one line is the whole mechanism. The assistant carries nothing between
projects on its own; a file in the repo is what makes the second project start
where the first one finished instead of rediscovering it over sixty revisions.

## The two rules that do the most work

**Decision → sign-off → build → validate.** Anything with a genuine fork gets
a written brief with the options and a recommended default, and waits for
sign-off before any code.

**Mutation-test every assertion.** Change the code so the assertion *should*
fail, and confirm it does. An assertion that cannot fail is not an assertion.

## Pushing

All commits come from Linux, never from Windows. Git for Windows defaults to
`core.autocrlf=true` and will rewrite line endings on checkout; committing
from there reintroduces the whole-file-modified phantom that took HUSTLER
several revisions to clear. Windows machines download, build and test — they
do not push.

## Keeping this repo honest

It is held to its own standard:

```bash
python3 tools/selftest.py
```

Assertions with a count, and CI that pins the count — because a framework that
demands a selftest of every project and has none of its own is not a framework,
it is a suggestion. It found four real defects on its first run, three of them in these tools, and
CI then found a fifth that the selftest structurally could not — see
`CHANGELOG.md`.

When a project teaches something that generalises, add it here — including the
mistakes. The failures transfer better than the successes, because the
successes are usually specific to the thing being built.
