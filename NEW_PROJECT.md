# Starting a new project

Step by step. Copy and paste, in order. Nothing here needs to be asked for.

Two routes: **the script** does the mechanical parts in one go, **by hand**
does the same thing explicitly if you would rather see every step. They
produce the same result.

---

## Route A — the script

```bash
~/playbook/tools/new-project.sh myproject
```

That creates `~/myproject` with the playbook, the CI workflow, the mutation
harness, a venv with pip upgraded, the empty documents, and a first commit. It
refuses to touch a directory that already exists, and it does **not** create or
push to GitHub — that stays manual so nothing lands in the wrong place.

Put it somewhere other than `$HOME` with a second argument:

```bash
~/playbook/tools/new-project.sh myproject ~/code
```

Then go to **step 6**.

---

## Route B — by hand

### 1. Directory and skeleton

```bash
mkdir -p ~/myproject/.github/workflows ~/myproject/tools && cd ~/myproject
```

### 2. Copy the playbook in

```bash
cp ~/playbook/PLAYBOOK.md ~/playbook/.gitattributes ~/myproject/
cp ~/playbook/templates/validate.yml ~/myproject/.github/workflows/
cp ~/playbook/templates/CONTRIBUTING.md ~/myproject/CONTRIBUTING.md
cp ~/playbook/tools/mutate.sh ~/playbook/tools/_mutate_apply.py ~/myproject/tools/
chmod +x ~/myproject/tools/mutate.sh
```

### 3. The environment — BEFORE any library

```bash
cd ~/myproject && python3 -m venv .venv && . .venv/bin/activate && python -m pip install --upgrade pip
```

Venv first, activate, upgrade pip, then install. Every machine, every project.
A stale pip resolves differently and will build from source where a wheel
exists. Section 1 of `PLAYBOOK.md` has the reasoning.

### 4. `.gitignore` and `requirements.txt`

```bash
cd ~/myproject && printf '__pycache__/\n*.pyc\n.venv/\nbuild/\ndist/\n' > .gitignore && printf '# Dependencies — these, and nothing else.\n# Adding to this file needs an explicit decision.\n' > requirements.txt
```

### 5. The documents, empty

Much harder to start at revision forty than on day one.

```bash
cd ~/myproject && printf '# Changelog\n\n---\n' > CHANGELOG.md && printf '# Known issues\n\n---\n' > KNOWN_ISSUES.md && printf '# Handoff\n\n**Status:** not started.\n\n---\n' > HANDOFF.md
```

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

The scaffolding everything else rests on. Build it early; retrofitting is
painful.

- [ ] **A selftest that reports a COUNT** — `--selftest` printing `[PASS]` per
      assertion and a total
- [ ] **A smoke test** — `--smoke`, does it start and run N times without
      falling over
- [ ] **A deterministic baseline** — a fixed-seed run whose output can be
      hashed, and the hash recorded
- [ ] Fill in `SELFTEST_COUNT` and `BASELINE_MD5` in
      `.github/workflows/validate.yml`
- [ ] Confirm CI is green on the first push, not on the twentieth

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
