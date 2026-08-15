# Starting a new project

A checklist, not a ceremony. Most of it is ten minutes on day one that pays
back for the life of the project.

## Day one

- [ ] `git init`, repo created on GitHub, first push **from Linux**
- [ ] `.gitattributes` with `* text=auto eol=lf` — settles line endings before
      they can become a problem
- [ ] `.gitignore` — build dirs, venvs, caches
- [ ] **Virtual environment created and activated, pip upgraded, THEN
      libraries installed** — in that order, every time:

      ```bash
      python3 -m venv .venv
      . .venv/bin/activate
      python -m pip install --upgrade pip
      pip install -r requirements.txt
      ```

      A stale pip resolves differently and will build from source where a
      wheel exists. Debian/Ubuntu/Pi OS refuse a bare `pip install` anyway
      (PEP 668) — that is the correct default, not an obstacle.
- [ ] `requirements.txt` (or equivalent) with **pinned** versions, and a
      comment saying that adding to it is a deliberate decision
- [ ] `.venv/` in `.gitignore` — never committed, always rebuildable from
      `requirements.txt` alone. If it cannot be, that file is wrong.
- [ ] `PLAYBOOK.md` copied in
- [ ] `LICENSE`

## The scaffolding that makes everything else work

- [ ] **A selftest that reports a COUNT.** `--selftest` printing `[PASS]` per
      assertion and a total. Everything else builds on this.
- [ ] **A smoke test.** `--smoke` — does it start and do its thing N times
      without falling over. Cheap, and catches the class of fault that no
      assertion describes.
- [ ] **A deterministic baseline.** A fixed-seed run whose output can be
      hashed. Record the hash. This is what makes large refactors
      trustworthy — it says "nothing changed" in a way nothing else can.
- [ ] **CI that pins the numbers** — `templates/validate.yml`. Not exit codes.
- [ ] **`tools/mutate.sh`** copied in, with `SRC` and `CMD` set.

## The documents

Create them empty on day one; they are much harder to start at revision forty.

- [ ] `CHANGELOG.md` — what changed and **why**, including fixes that were
      wrong first and what the wrong one taught
- [ ] `KNOWN_ISSUES.md` — open problems shipped with their diagnoses
- [ ] `HANDOFF.md` — current state, architecture doctrine, standing
      exceptions that must not be "tidied away"
- [ ] `CONTRIBUTING.md` — the baseline a newcomer runs, and why each rule
      exists

## Every session afterwards

Activate the venv first. A session that starts by installing something
system-wide has already gone wrong:

```bash
cd ~/project && . .venv/bin/activate
```

## Session one with an assistant

Open with:

> New project. Read `PLAYBOOK.md` first — that's how we work.
> Then `HANDOFF.md` for where things are.

Then, before any code: **confirm the baseline yourself**. Clone fresh, run the
chain, report the actual numbers. Do not trust numbers from a previous session
or from the human's memory — including your own notes.

## Per release, thereafter

- [ ] Full chain run, **actual numbers reported**
- [ ] One new assertion per feature, mutation-tested, each mutant verified as
      applied
- [ ] Version bumped in exactly one place, with everything else reading it
- [ ] CI counts bumped in the same commit
- [ ] Docs swept for stale version and count claims
- [ ] **Verified from a fresh clone after pushing** — not from the working
      directory

## Branching

Trunk is fine for most work. Branch when the work is inherently
trial-and-error against something you cannot validate locally — a CI-only
build, a platform you do not have. Name it `develop` if your CI already
watches that branch, and check `git branch --show-current` before copying
files in.
