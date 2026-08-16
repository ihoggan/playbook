#!/usr/bin/env python3
"""__NAME__ — entry point.

THIS IS A SPINE, NOT A PROJECT. Everything here is meant to be replaced except
the three flags, which are meant to be kept and grown:

    --selftest      prints [PASS] per assertion and a TOTAL COUNT
    --smoke N       runs the thing N times and exits non-zero if it falls over
    --snap PATH     writes a DETERMINISTIC output that can be hashed

They ship on day one because retrofitting them is painful, and because CI is
green on the first push only if there is something honest for it to check. The
counts in .github/workflows/validate.yml were filled in by running this file,
not guessed.

The demo core below (a version string and a fixed-seed sequence) exists so the
first assertions are real ones. Delete it once you have your own — but keep the
shape: pure functions, asserted on what they RETURN, never on what the source
text says.
"""

import hashlib
import sys

# Declared ONCE. Packaging, docs and CLI all read it from here; nothing carries
# a second copy. See PLAYBOOK.md — a version in two places is a version that
# will disagree with itself.
VERSION = "0.1.0"


# ---------------------------------------------------------------------------
# The pure core. Replace this with yours.
# ---------------------------------------------------------------------------

def lcg(seed, n):
    """n values of a linear congruential generator. Deterministic everywhere.

    Written out rather than taken from `random` so the baseline hash below
    cannot drift with a Python release. This is what makes --snap meaningful.
    """
    x = seed & 0xFFFFFFFF
    out = []
    for _ in range(n):
        x = (1664525 * x + 1013904223) & 0xFFFFFFFF
        out.append(x)
    return out


def version_parts(text):
    """('1.2.3') -> (1, 2, 3). Raises on anything that is not three integers."""
    bits = text.split(".")
    if len(bits) != 3:
        raise ValueError("version must have three parts: %r" % text)
    return tuple(int(b) for b in bits)


def baseline_bytes(seed=20260816, n=256):
    """The deterministic artefact --snap writes. Hash this, pin the hash."""
    return ("\n".join(str(v) for v in lcg(seed, n)) + "\n").encode("utf-8")


# ---------------------------------------------------------------------------
# Selftest — reports a COUNT, because an exit code cannot tell you the file
# was truncated. Add one assertion per feature. Then MUTATE the code and
# confirm the assertion fails: tools/mutate.sh.
# ---------------------------------------------------------------------------

def raises(fn, *args):
    """True if fn(*args) raises. Lets a selftest assert on REJECTION.

    Worth having from the start: a guard clause that nothing tests is a guard
    clause that can be deleted without a single assertion noticing.
    """
    try:
        fn(*args)
    except Exception:
        return True
    return False


def selftest():
    n = 0
    bad = 0

    def check(label, fn):
        """fn is a CALLABLE, not a value, so an exception inside one assertion
        becomes a [FAIL] instead of aborting the run. A suite that stops early
        reports a smaller count, and a smaller count is indistinguishable at a
        glance from a smaller file."""
        nonlocal n, bad
        n += 1
        try:
            ok = bool(fn())
        except Exception as exc:
            print("[FAIL] %d %s -- raised %s: %s"
                  % (n, label, type(exc).__name__, exc))
            bad += 1
            return
        if ok:
            print("[PASS] %d %s" % (n, label))
        else:
            print("[FAIL] %d %s" % (n, label))
            bad += 1

    # Pinned LITERALS, not a comparison of the function against itself. A
    # circular assertion is the commonest way to write one that cannot fail.
    check("lcg fixed seed is reproducible",
          lambda: lcg(20260816, 3) == [1565448431, 2469802370, 597377785])

    check("lcg length is exactly n",
          lambda: len(lcg(1, 7)) == 7)

    # Note what this does NOT do: compare version_parts(VERSION) against
    # tuple(int(b) for b in VERSION.split(".")). That would be the function
    # checked against a copy of its own logic, and it would pass for any
    # mutant that broke both the same way.
    check("version parses to a literal triple",
          lambda: version_parts("1.2.3") == (1, 2, 3))

    check("declared version is well formed",
          lambda: len(version_parts(VERSION)) == 3)

    # This one exists because mutation testing said so. Without it, gutting
    # the length guard in version_parts to `if False:` SURVIVED the whole
    # suite -- every assertion above passes a well-formed version, so none of
    # them could ever reach the rejection path.
    check("malformed versions are rejected",
          lambda: raises(version_parts, "1.2")
          and raises(version_parts, "1.2.3.4")
          and raises(version_parts, "1.2.x"))

    # A case a healthy run cannot produce, which is the whole point: it is
    # the only way to tell "reported what it did" from "reported what it was
    # asked to do".
    check("smoke reports work done, not work requested",
          lambda: smoke_line(3, 90) == "smoke: 3 of 90 iterations")

    check("baseline artefact is stable",
          lambda: hashlib.md5(baseline_bytes()).hexdigest()
          == "135e2fc4ac5bb293582e750fc7f1c0e0")

    print("%d assertions, %d failed" % (n, bad))
    return 1 if bad else 0


def smoke_line(done, frames):
    """The smoke report, as a pure function so it can be asserted on.

    Split out because mutation testing caught it: reporting the number asked
    for instead of the number completed is invisible from outside when the
    loop is healthy, so no end-to-end check can ever see the difference. The
    only way to assert it is to make it pure and hand it a case that cannot
    occur in a working run.
    """
    return "smoke: %d of %d iterations" % (done, frames)


def smoke(frames):
    """Does it start and keep going. The cheapest possible 'still works'.

    Reports the iterations it COMPLETED, not the number it was asked for. An
    empty loop that prints the request still says "90" and exits 0.
    """
    done = 0
    for i in range(frames):
        lcg(i, 8)
        done += 1
    print(smoke_line(done, frames))
    return 0 if done == frames else 1


def snap(path):
    with open(path, "wb") as fh:
        fh.write(baseline_bytes())
    print("snap: %s" % path)
    return 0


def main(argv):
    if "--version" in argv:
        print(VERSION)
        return 0
    if "--selftest" in argv:
        return selftest()
    if "--smoke" in argv:
        i = argv.index("--smoke")
        frames = int(argv[i + 1]) if len(argv) > i + 1 else 90
        return smoke(frames)
    if "--snap" in argv:
        i = argv.index("--snap")
        if len(argv) <= i + 1:
            print("--snap needs a path")
            return 2
        return snap(argv[i + 1])

    print("__NAME__ %s" % VERSION)
    print("  --selftest        assertions, with a count")
    print("  --smoke [N]       run N iterations")
    print("  --snap PATH       write the deterministic baseline")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
