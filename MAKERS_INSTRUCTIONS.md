# Maker's Instructions

Starting a new project. For an existing one, see `ADOPT_EXISTING.md`.

Step by step. Copy and paste, in order. Nothing here needs to be asked for.

Two routes: **the script** does the mechanical parts in one go, **by hand**
does the same thing explicitly if you would rather see every step.

They produce the same result, and now that is guaranteed rather than promised:
the by-hand route is `--dry-run`, which prints the exact commands the script
would run. It used to be a second copy of the list, and the two had already
drifted — the script copied `MAKERS_INSTRUCTIONS.md` into the new project and
the by-hand route did not.

---

## Route A — the script

Run it with no arguments and it asks:

```bash
~/playbook/tools/new-project.sh
```

```
  Howdy Maker.

  What's this project going to be called?
  >
```

Or name it up front and skip the questions:

```bash
~/playbook/tools/new-project.sh myproject
```

That creates `~/myproject` with the playbook, the CI workflow, the mutation
harness, a README and licence, a venv with pip upgraded, the empty documents,
a **working spine** (`main.py` with `--selftest`, `--smoke` and `--snap`), and
a first commit. It refuses to touch a directory that already exists, and it
does **not** create or push to GitHub — that stays manual so nothing lands in
the wrong place.

Put it somewhere other than `$HOME` with a second argument:

```bash
~/playbook/tools/new-project.sh myproject ~/code
```

Then go to **step 6**.

---

## Route B — by hand

Print every command the script would run, read them, then run them yourself:

```bash
~/playbook/tools/new-project.sh --dry-run myproject
```

Nothing is executed. The output is the by-hand route, generated from
`SCAFFOLD_MANIFEST` — so it cannot fall out of step with what the script
actually does.

Two steps are worth knowing by heart rather than reading off a printout.

**The environment, before any library:**

```bash
cd ~/myproject && python3 -m venv .venv && . .venv/bin/activate && python -m pip install --upgrade pip
```

Venv first, activate, upgrade pip, then install. Every machine, every project.
A stale pip resolves differently and will build from source where a wheel
exists. Section 1 of `PLAYBOOK.md` has the reasoning.

**The CI numbers come from a real run**, never from a guess:

```bash
cd ~/myproject && python main.py --selftest | grep -c "\[PASS\]"
cd ~/myproject && python main.py --snap /tmp/b.out && md5sum /tmp/b.out
```

Those two numbers go into `SELFTEST_COUNT` and `BASELINE_MD5` in
`.github/workflows/validate.yml`. Route A does this for you.

---

## 6. Git, local

```bash
cd ~/myproject && git init -b main && git add .gitattributes .gitignore PLAYBOOK.md CONTRIBUTING.md CHANGELOG.md KNOWN_ISSUES.md HANDOFF.md requirements.txt .github tools && git commit -m "scaffold from playbook" && git status --short
```

Named files, never `git add -A`.

## 7. GitHub

Create the empty repo at **https://github.com/new** — same name, and **no**
README, licence or `.gitignore`, because you already have them and they would
collide.

```bash
cd ~/myproject && git remote -v
```

If that prints nothing, add the remote below. If it prints the *wrong* URL,
use `git remote set-url origin <url>` instead — `remote add` fails on an
existing remote, and in an `&&` chain that silently skips the push after it.

```bash
cd ~/myproject && git remote add origin https://github.com/<you>/myproject.git && git push -u origin main
```

## 8. Verify from a fresh clone

Not from the directory you have been working in.

```bash
cd /tmp && rm -rf verify && git clone -q https://github.com/<you>/myproject.git verify && cd verify && git log --oneline && git status --porcelain && echo "(empty above = clean)" && find . -type f -not -path "./.git/*" | sort
```

Anything showing as modified straight after checkout is a real problem. `find`
rather than `ls`, so dotfiles actually appear.

---

## Every session after that

```bash
cd ~/myproject && . .venv/bin/activate && git branch --show-current && git status --short
```

A session that starts by installing something system-wide has already gone
wrong.

## Session one with an assistant

> New project. Read `PLAYBOOK.md` in the repo first — that's how we work.
> Then `HANDOFF.md` for where things are.

Then, before any code: **have it confirm the baseline itself** — clone fresh,
run the chain, report actual numbers. Not numbers from a previous session, its
own notes, or your memory.

---

## Before the project is really underway

The scaffolding everything else rests on. It now ships with the scaffold
rather than sitting on a list of things to get round to — `main.py` arrives
with `--selftest`, `--smoke` and `--snap` already working, and the CI counts
already filled in from a real run. So CI is green on the **first** push, which
is a promise this document used to make and could not keep: the workflow
pointed at a `main.py` that did not exist yet.

What is left is to make it yours:

- [ ] Replace the demo core in `main.py` with the real thing
- [ ] Keep the three flags. Grow the selftest one assertion per feature
- [ ] Re-pin `SELFTEST_COUNT` and `BASELINE_MD5` when the spine goes; the
      baseline hash is only meaningful once it hashes YOUR output
- [ ] Confirm CI is still green after the first real commit

## Per release, thereafter

- [ ] Full chain run, **actual numbers reported**
- [ ] One new assertion per feature, mutation-tested, each mutant verified as
      applied
- [ ] Version bumped in exactly one place, everything else reading it
- [ ] CI counts bumped in the same commit
- [ ] Docs swept for stale version and count claims
- [ ] Verified from a fresh clone after pushing

## Branching

Trunk is fine for most work. Branch when the work is inherently
trial-and-error against something you cannot validate locally — a CI-only
build, a platform you do not have. Name it `develop` if your CI already
watches that branch, and check `git branch --show-current` before copying
files in.
