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
| `NEW_PROJECT.md` | **Step-by-step commands for starting a project.** Start here. |
| `templates/validate.yml` | CI that enforces **counts**, not just exit codes. |
| `templates/CONTRIBUTING.md` | Skeleton for a new repo's contributor guide. |
| `tools/mutate.sh` | Mutation-test helper that hard-fails on a missed anchor. |
| `tools/new-project.sh` | Scaffolds a new project in one command. |

## Using it on a new project

Copy the document into the new repo, and point the assistant at it in the
first message of the first session:

```bash
cp ~/playbook/PLAYBOOK.md ~/newproject/
cp ~/playbook/templates/validate.yml ~/newproject/.github/workflows/
cp ~/playbook/tools/mutate.sh ~/newproject/tools/
```

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

When a project teaches something that generalises, add it here — including the
mistakes. The failures transfer better than the successes, because the
successes are usually specific to the thing being built.
