# Contributing

## Confirm the baseline first

Before changing anything, clone fresh and run the chain. Report the actual
numbers, never "passed".

```bash
python -m py_compile main.py
python main.py --selftest      # expect: ALL PASS (N assertions)
python main.py --smoke
python main.py --snap /tmp/b.png && md5sum /tmp/b.png
```

Counting matters more than it looks:

```bash
python main.py --selftest | grep -c "\[PASS\]"     # expect N, not "passes"
```

A truncated file whose remaining assertions all pass exits 0 and looks green.
That is why CI pins the count and why you should check it by eye too.

## Every change

- One new assertion per feature, on the pure testable core — not the
  framework-dependent wrapper.
- **Mutation-test it.** Break the code so the assertion should fail, and
  confirm it does. Verify the mutation actually applied; a missed anchor looks
  exactly like a caught mutant.
- Bump the CI counts in the same commit as the assertion.
- Say **why** in the changelog, not just what.

## Line endings

Commit from Linux. Git for Windows rewrites line endings on checkout and
committing from there can make every file look modified in a fresh clone.
Windows machines download, build and test — they do not push.

## Never `git add -A`

Name every file. A sweep pulls in build artefacts and scratch files that then
have to be untangled from history.
