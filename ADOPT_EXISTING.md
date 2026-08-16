# Bringing an existing project up to standard

For the scripts and half-finished projects that already exist. The order
matters: **do not start adding features.** Get the project to a state where
change is safe, then change it.

## 1. Get it into the shape everything else assumes

```bash
mkdir -p ~/oldproject/.github/workflows ~/oldproject/tools && cd ~/oldproject
cp ~/playbook/PLAYBOOK.md ~/playbook/MAKERS_INSTRUCTIONS.md ~/playbook/.gitattributes .
cp ~/playbook/templates/validate.yml .github/workflows/
cp ~/playbook/templates/CONTRIBUTING.md ./CONTRIBUTING.md
cp ~/playbook/tools/mutate.sh ~/playbook/tools/_mutate_apply.py tools/
chmod +x tools/mutate.sh
python3 -m venv .venv && . .venv/bin/activate && python -m pip install --upgrade pip
```

Then work out what it actually depends on and pin it:

```bash
python -c "import ast,sys;print(sorted({n.names[0].name.split('.')[0] for n in ast.walk(ast.parse(open(sys.argv[1]).read())) if isinstance(n,ast.Import)} | {n.module.split('.')[0] for n in ast.walk(ast.parse(open(sys.argv[1]).read())) if isinstance(n,ast.ImportFrom) and n.module}))" yourscript.py
```

Install what it needs, then freeze **only** those into `requirements.txt` with
exact versions. Not `pip freeze` wholesale — that captures the accidents of one
machine.

## 2. Establish a baseline BEFORE changing anything

This is the whole point, and it is the step most likely to be skipped.

- Does it run? Record exactly how it is invoked.
- Is there any output that is deterministic — a fixed seed, a known input
  file, a generated image or report? **Hash it and write the hash down.**
- If nothing is deterministic yet, make one thing deterministic. A `--seed`
  flag is usually enough. Without a baseline, no refactor can be proven safe,
  and everything after this is guesswork.

Commit that state untouched, before any tidying. The first commit should be
the project exactly as it was.

## 3. Add the three pieces of scaffolding

In this order, because each one makes the next safer:

1. **`--smoke`** — runs the thing N times or for N frames and exits non-zero
   on failure. Cheapest possible "does it still work".
2. **`--selftest`** — prints `[PASS]` per assertion and a total count. Start
   with two or three assertions on whatever is most load-bearing. It does not
   need to be complete; it needs to exist and to count.
3. **A hashable baseline** — the deterministic output from step 2, produced on
   demand.

Then fill in `SELFTEST_COUNT` and `BASELINE_MD5` in
`.github/workflows/validate.yml` and push. CI green on the first push.

## 4. Only now, change things

Every change from here follows the playbook: brief for anything with a fork,
one assertion per feature, mutation-tested, actual numbers reported, verified
from a fresh clone.

## What to hand an assistant

Point it at the repo and say:

> Existing project being brought up to standard. Read `PLAYBOOK.md` and
> `ADOPT_EXISTING.md` first. Here is the script. Before proposing anything,
> tell me what it does, what is deterministic about it, and what the smallest
> honest baseline would be.

Resist the urge to let it start improving the code. The first session should
produce a baseline and a plan, not a rewrite. A rewrite you cannot prove is
identical is not an improvement, it is a new project wearing the old one's
name.

## The trap

The temptation with an old project is to fix the thing that has been annoying
you for a year. Do not. Until there is a baseline, you cannot tell the
difference between fixing it and breaking something else quietly.
