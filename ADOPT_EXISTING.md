# Bringing an existing project up to standard

For the scripts and half-finished projects that already exist. The order
matters: **do not start adding features.** Get the project to a state where
change is safe, then change it.

## 1. Get it into the shape everything else assumes

One command. It copies the practices, the CI workflow and the mutation harness
into a directory that already exists, and touches nothing else — no venv, no
git, no documents, and **nothing that would overwrite the work you are
adopting**. Your `main.py`, `README.md` and `LICENSE` stay exactly as they are.

```bash
~/playbook/tools/new-project.sh --files-only ~/oldproject
```

What arrives is read from `SCAFFOLD_MANIFEST` in the playbook, which is the one
place that list lives. This page used to carry its own copy of it, and copies
drift: the version in `README.md` copied `mutate.sh` without
`_mutate_apply.py`, which it cannot run without.

Then the environment, before any library:

```bash
cd ~/oldproject && python3 -m venv .venv && . .venv/bin/activate && python -m pip install --upgrade pip
```

Then work out what it actually depends on and pin it. Every `.py` file, not
just the entry point:

```bash
python3 - *.py <<'EOF'
import ast, sys
mods = set()
for path in sys.argv[1:]:
    tree = ast.parse(open(path).read())
    for n in ast.walk(tree):
        if isinstance(n, ast.Import):
            for a in n.names:                 # `import a, b, c` is ONE node
                mods.add(a.name.split(".")[0])
        elif isinstance(n, ast.ImportFrom) and n.module and n.level == 0:
            mods.add(n.module.split(".")[0])
print(sorted(mods - set(sys.stdlib_module_names)))
EOF
```

The earlier version of this scanned one file and read `n.names[0]` only, so
`import sys, json, os` reported `sys` and silently dropped the other two. It
was found by adopting a real project rather than by reading it, which is the
argument for step 2 in miniature.

Install what it needs, then freeze **only** those into `requirements.txt` with
exact versions. Not `pip freeze` wholesale — that captures the accidents of one
machine.

### What arrives already knowing it is an adoption

`--files-only` skips anything that would overwrite your work, and copies a
`.gitignore` **only if you do not already have one** — you will want it before
the next step, because the venv you just created is otherwise sitting in
`git status`.

Two things it cannot guess:

- **`.github/workflows/validate.yml` names its entry point once, at the top:**
  `ENTRY: main.py`. Your script is not called `main.py`. Change that line.
- **It arrives pinned to the numbers of the scaffold's demo spine**, which are
  not yours. CI is correctly red until step 3 fills them in.

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
`.github/workflows/validate.yml` — **read off a real run, not guessed** — and
push:

```bash
python main.py --selftest | grep -c "\[PASS\]"
python main.py --snap /tmp/b.out && md5sum /tmp/b.out
```

The template arrives pinned to the numbers of the *spine*, which is not your
project. Until you replace them, CI is correctly red. That is the one case
where red on the first push is the honest answer — the alternative is a
workflow that passes without checking anything.

**Expect the lint job to fail on the first push too, and do not weaken it.**
Existing code has almost certainly never seen `isort`, and `import sys, json,
os` fails `--check-only` immediately. Fix it rather than the workflow, in a
commit that changes nothing else:

```bash
python -m isort $(git ls-files '*.py') && python -m pyflakes $(git ls-files '*.py')
git add -u && git commit -m "isort: no behaviour change"
```

Doing that *after* step 2's baseline is deliberate — it is the first change
the baseline proves safe, which is a useful rehearsal for every change after
it.

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
