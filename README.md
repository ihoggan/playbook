# playbook

How I run projects, and the reusable pieces that go with it.

Distilled from HUSTLER — a UK blackball pool physics sandbox that ran to
seventy revisions. Every practice here earned its place by catching something
real, and the failures in `PLAYBOOK.md` section 11 are as useful as
the successes.

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

## Using it on a new project

```bash
~/playbook/tools/new-project.sh              # asks
~/playbook/tools/new-project.sh myproject    # doesn't
```

You get the practices, CI that enforces counts, the mutation harness, a README
and licence, and a **working spine** — a `main.py` that already has
`--selftest`, `--smoke` and `--snap`, with the CI counts filled in from a real
run of it. Green on the first push rather than the twentieth.

For a project that already exists:

```bash
~/playbook/tools/new-project.sh --files-only ~/oldproject   # overwrites nothing
```

What gets copied is listed in `SCAFFOLD_MANIFEST` and nowhere else. This
section used to carry its own copy of that list and it was **wrong** — it
copied `mutate.sh` without `_mutate_apply.py`, which it cannot run without.
That is what `tools/selftest.py` is for.

Then open the session with something like:

> New project. Read `PLAYBOOK.md` in the repo first — that's how we
> work. Then read `HANDOFF.md` for where the project is up to.

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
it is a suggestion. It found four real defects on its first run, three of them
in these tools.

When a project teaches something that generalises, add it here — including the
mistakes. The failures transfer better than the successes, because the
successes are usually specific to the thing being built.
