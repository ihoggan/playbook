# __NAME__

One line on what this is. Replace this sentence before you replace anything
else — it is the first thing anyone sees.

## Run it

```bash
python3 -m venv .venv && . .venv/bin/activate && python -m pip install --upgrade pip
pip install -r requirements.txt
python main.py
```

## Validate it

Every change runs the whole chain, and the numbers get reported — never
"passed".

```bash
python -m py_compile main.py
python main.py --selftest        # assertions, with a count
python main.py --smoke 90        # does it start and keep going
python main.py --snap /tmp/b.out && md5sum /tmp/b.out
```

The counts CI enforces live in `.github/workflows/validate.yml`. Bumping them
is deliberate and happens in the same commit as the change.

## How this project is run

`PLAYBOOK.md` — the working practices, and the mistakes behind each one.
`CONTRIBUTING.md` — the baseline to run before changing anything.
`CHANGELOG.md` — what changed and **why**.
`KNOWN_ISSUES.md` — open problems, each shipped with its diagnosis.
`HANDOFF.md` — current state and the standing exceptions.

## Licence

MIT. See `LICENSE`.
