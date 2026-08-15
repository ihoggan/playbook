"""Apply one mutation, or fail loudly. Used by mutate.sh.

Exits non-zero unless the search text matched EXACTLY once. A mutation that
did not apply must never look like a mutation the assertion caught — that is
the whole reason this is a separate, checkable step.
"""
import sys

path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path, encoding="utf-8").read()
n = s.count(old)
if n != 1:
    print("   anchor matched %d times (need exactly 1)" % n)
    sys.exit(1)
open(path, "w", encoding="utf-8").write(s.replace(old, new))
sys.exit(0)
