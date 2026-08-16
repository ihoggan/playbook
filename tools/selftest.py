#!/usr/bin/env python3
"""selftest.py — the playbook checking itself.

This exists because the playbook demanded a selftest, a smoke test and pinned
CI counts from every project it touched, and had none of its own. Four real
defects were sitting in it at one commit old, three of them in these very
tools:

  * the copy-in list lived in four places and had already drifted — one route
    copied MAKERS_INSTRUCTIONS.md and the other did not, and README's list
    copied mutate.sh without _mutate_apply.py, which it cannot run without
  * the scaffolded CI could not be green on the first push, which three
    documents promised it would be
  * the mutation harness printed a number to interpret rather than a verdict,
    so a survivor and a catch looked the same
  * mutate.sh located its helper with ${BASH_SOURCE[0]}, which zsh does not
    define — the shell the author actually uses

Every assertion below corresponds to one of those, or to the shape of fault
that produced it. Run it:

    python3 tools/selftest.py

Reports [PASS] per assertion and a total count, exactly as it asks of every
project. --smoke does the same work without the detail, for CI.
"""

import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "SCAFFOLD_MANIFEST")
SCAFFOLD = os.path.join(ROOT, "tools", "new-project.sh")

KNOWN_FLAGS = {"render", "new-only", "keep-existing"}
PLACEHOLDERS = ("__NAME__", "__YEAR__", "__HOLDER__")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def sh(args, cwd=None, env=None, check=False, no_playbook=False):
    """Run a command, return (exit code, combined output).

    no_playbook drops $PLAYBOOK entirely. Everything here used to set it
    unconditionally, which is precisely why nothing noticed that the script
    defaulted to $HOME/playbook and refused to run from a clone anywhere else.
    A test fixture that always supplies the value cannot test the default.
    """
    e = dict(os.environ)
    e["PLAYBOOK"] = ROOT
    if env:
        e.update(env)
    if no_playbook:
        e.pop("PLAYBOOK", None)
        e["HOME"] = "/nonexistent-home-on-purpose"
    p = subprocess.run(args, cwd=cwd, env=e, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True)
    if check and p.returncode != 0:
        raise RuntimeError("%s failed (%d):\n%s" % (args, p.returncode, p.stdout))
    return p.returncode, p.stdout


def manifest_entries():
    """[(source, dest, set(flags))] — parsed the same way the script parses it."""
    out = []
    with open(MANIFEST, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            bits = line.split(":")
            out.append((bits[0], bits[1], set(bits[2:])))
    return out


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def code_only(text):
    """Drop # comment lines.

    An absence assertion has to look at CODE, not at prose describing the code.
    Both of the absence checks below failed on their first run against the
    comment that explains why the thing is banned — which is a false alarm, and
    a false alarm is how an assertion earns the right to be ignored.
    """
    return "\n".join(l for l in text.splitlines()
                     if not l.lstrip().startswith("#"))


def scaffold(tmp, name="demo", extra=()):
    """Scaffold a project into tmp and return its path plus the run output."""
    rc, out = sh(["bash", SCAFFOLD, "--no-venv", *extra, name, tmp])
    return os.path.join(tmp, name), rc, out


def tracked_files(path):
    rc, out = sh(["git", "ls-files"], cwd=path)
    return sorted(x for x in out.splitlines() if x)


# ---------------------------------------------------------------------------
# The mutation harness fixtures.
#
# Two modules that differ ONLY in whether their assertion is honest. Anything
# that reports the same verdict for both is not telling us anything.
# ---------------------------------------------------------------------------

FIXTURE_HONEST = '''\
import sys

def seed(n):
    return (n * 37 + 11) % 1000

def selftest():
    ok = 0
    # Pinned literals. A mutant that changes the multiplier must fail this.
    for i, (a, b) in enumerate([(1, 48), (2, 85), (3, 122)], 1):
        if seed(a) == b:
            print("[PASS] %d seed(%d)" % (i, a)); ok += 1
        else:
            print("[FAIL] %d seed(%d)" % (i, a))
    print("%d passed" % ok)
    return 0

if "--selftest" in sys.argv:
    sys.exit(selftest())
'''

FIXTURE_CIRCULAR = '''\
import sys

def seed(n):
    return (n * 37 + 11) % 1000

def selftest():
    ok = 0
    # CIRCULAR ON PURPOSE: the function compared against its own logic. No
    # mutation of the constants can ever make this fail.
    for i, a in enumerate([1, 2, 3], 1):
        if seed(a) == (a * 37 + 11) % 1000 or True:
            print("[PASS] %d seed(%d)" % (i, a)); ok += 1
        else:
            print("[FAIL] %d seed(%d)" % (i, a))
    print("%d passed" % ok)
    return 0

if "--selftest" in sys.argv:
    sys.exit(selftest())
'''

FIXTURE_BROKEN = FIXTURE_HONEST.replace("(1, 48)", "(1, 49)")


def run_harness(tmp, fixture, mutants, workdir_name):
    """Drive mutate.sh over a fixture. Returns the harness output and exit code."""
    d = os.path.join(tmp, workdir_name)
    os.makedirs(os.path.join(d, "tools"), exist_ok=True)
    with open(os.path.join(d, "main.py"), "w", encoding="utf-8") as fh:
        fh.write(fixture)
    for f in ("mutate.sh", "_mutate_apply.py"):
        shutil.copy(os.path.join(ROOT, "tools", f), os.path.join(d, "tools", f))

    # Set EVERY variable the harness reads, including the ones we do not want.
    # mutate.sh is configured by environment variables, so a caller that is
    # itself being driven by the harness inherits TREE and RUN and stages the
    # wrong thing. Found by running it: the outer harness exported TREE=. and
    # this inner one quietly tested the wrong tree.
    lines = ["export SRC=main.py CMD=--selftest WORK=%s/.mutwork" % d,
             "export TREE= RUN=",
             ". tools/mutate.sh"]
    for name, old, new in mutants:
        lines.append('run_mutant "%s" "%s" "%s"' % (name, old, new))
    lines.append("mutation_summary")
    lines.append('echo "SUMMARY_EXIT=$?"')
    return sh(["bash", "-c", "\n".join(lines)], cwd=d)


# ---------------------------------------------------------------------------
# The suite
# ---------------------------------------------------------------------------

def selftest(verbose=True):
    n = 0
    bad = 0

    def check(label, fn):
        nonlocal n, bad
        n += 1
        try:
            ok = bool(fn())
        except Exception as exc:
            if verbose:
                print("[FAIL] %d %s -- raised %s: %s"
                      % (n, label, type(exc).__name__, exc))
            bad += 1
            return
        if ok:
            if verbose:
                print("[PASS] %d %s" % (n, label))
        else:
            if verbose:
                print("[FAIL] %d %s" % (n, label))
            bad += 1

    entries = manifest_entries()

    # -- the manifest itself ------------------------------------------------

    check("manifest is not empty",
          lambda: len(entries) >= 7)

    check("every manifest source exists in the playbook",
          lambda: all(os.path.isfile(os.path.join(ROOT, s)) for s, _, _ in entries))

    check("no destination is claimed twice",
          lambda: len({d for _, d, _ in entries}) == len(entries))

    check("no manifest flag is a typo",
          lambda: all(f in KNOWN_FLAGS for _, _, fl in entries for f in fl))

    check("the harness ships with its helper",
          lambda: {"tools/mutate.sh", "tools/_mutate_apply.py"}
          <= {d for _, d, _ in entries})

    # The one that would have caught the README bug: no document may carry its
    # own copy of the copy-in list. An ABSENCE assertion, which is the kind
    # that finds the copy you did not know about.
    def no_rival_lists():
        pat = re.compile(r"^\s*cp\s+.*playbook", re.M)
        for doc in ("README.md", "MAKERS_INSTRUCTIONS.md", "ADOPT_EXISTING.md"):
            if pat.search(read(os.path.join(ROOT, doc))):
                return False
        return True

    check("no document carries a rival copy of the manifest",
          no_rival_lists)

    # Section 9 asks every project for these three. The repo that asks went
    # without them until someone noticed -- the same shape as having no
    # selftest of its own.
    # The zip-based delivery route strips permission bits: Python's zipfile
    # does not restore them on extract. So a round-trip through a delivered
    # archive leaves these unrunnable, and the only symptom is "command not
    # found" at the moment someone tries to use the harness.
    check("the repo's own shell tools are executable",
          lambda: all(os.access(os.path.join(ROOT, f), os.X_OK) for f in
                      ("tools/mutate.sh", "tools/new-project.sh")))

    check("the playbook carries the documents it asks of others",
          lambda: all(os.path.isfile(os.path.join(ROOT, d)) for d in
                      ("CHANGELOG.md", "KNOWN_ISSUES.md", "HANDOFF.md")))

    # -- the scaffolder -----------------------------------------------------

    with tempfile.TemporaryDirectory() as tmp:
        proj, rc, out = scaffold(tmp)

        check("scaffold exits clean",
              lambda: rc == 0)

        check("scaffold delivers exactly the manifest destinations",
              lambda: {d for _, d, _ in entries} <= set(tracked_files(proj)))

        check("scaffold tracks the documents it generates",
              lambda: {"CHANGELOG.md", "KNOWN_ISSUES.md", "HANDOFF.md",
                       ".gitignore", "requirements.txt"} <= set(tracked_files(proj)))

        # Fork E: a portfolio repo whose landing page is blank.
        check("scaffold delivers a README and a licence",
              lambda: {"README.md", "LICENSE"} <= set(tracked_files(proj)))

        def no_placeholders():
            for dirpath, dirnames, names in os.walk(proj):
                dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
                for fn in names:
                    body = read(os.path.join(dirpath, fn))
                    if any(p in body for p in PLACEHOLDERS):
                        return False
            return True

        check("nothing ships with an unsubstituted placeholder",
              no_placeholders)

        # Mutation testing said so: commenting out the chmod SURVIVED the whole
        # suite. A harness that arrives unrunnable is a harness nobody runs.
        # The one thing about the scaffold that nothing can check automatically
        # arrives as a written-down issue instead, so it is carried rather than
        # remembered.
        check("the scaffold hands over the re-pin as a tracked issue",
              lambda: "BASELINE_MD5"
              in read(os.path.join(proj, "KNOWN_ISSUES.md")))

        check("the mutation harness arrives executable",
              lambda: os.access(os.path.join(proj, "tools/mutate.sh"), os.X_OK))

        # -- the spine, and the promise that CI is green on the first push --

        ci = read(os.path.join(proj, ".github/workflows/validate.yml"))
        pinned_count = int(re.search(r"SELFTEST_COUNT:\s*(\d+)", ci).group(1))
        pinned_md5 = re.search(r'BASELINE_MD5:\s*"([0-9a-f]*)"', ci).group(1)

        rc_st, st = sh(["python3", "main.py", "--selftest"], cwd=proj)
        real_count = st.count("[PASS]")

        check("the spine passes its own selftest",
              lambda: rc_st == 0 and st.count("[FAIL]") == 0 and real_count > 0)

        # THE FIRST-PUSH PROMISE. Pinned numbers that do not match a real run
        # mean a red X on a brand-new repo, which is what three documents
        # promised would not happen.
        check("CI's pinned assertion count matches a real run",
              lambda: pinned_count == real_count)

        snap = os.path.join(tmp, "baseline.out")
        rc_sn, _ = sh(["python3", "main.py", "--snap", snap], cwd=proj)
        real_md5 = hashlib.md5(open(snap, "rb").read()).hexdigest()

        check("CI's pinned baseline hash matches a real run",
              lambda: rc_sn == 0 and pinned_md5 == real_md5)

        rc_sm, sm = sh(["python3", "main.py", "--smoke", "90"], cwd=proj)
        # "90 in sm" also passed when the loop body never ran, because the old
        # smoke printed the number it was ASKED for. Pin the completed count.
        check("the spine smoke test completes every iteration",
              lambda: rc_sm == 0 and "smoke: 90 of 90 iterations" in sm)

        # Four hardcoded copies of "main.py" is four places an adopter misses.
        check("CI names its entry point once, as a variable",
              lambda: "ENTRY: main.py" in ci
              and "python main.py" not in ci)

        # The template must ship pinned to the same numbers, or the very first
        # thing --files-only hands an adopted project is a wrong count.
        tmpl = read(os.path.join(ROOT, "templates/validate.yml"))
        check("the CI template ships pinned to the spine's real numbers",
              lambda: re.search(r"SELFTEST_COUNT:\s*%d\b" % real_count, tmpl)
              and real_md5 in tmpl)

    # -- the scaffolder's refusals ------------------------------------------
    #
    # The scaffolder pins CI's numbers by running the spine. If the spine is
    # broken it must REFUSE, not pin the numbers a broken run produced. Nothing
    # exercised that guard, so deleting it survived the whole suite.

    with tempfile.TemporaryDirectory() as tmp:
        broken = os.path.join(tmp, "brokenbook")
        shutil.copytree(ROOT, broken, ignore=shutil.ignore_patterns(".git"))
        spine = os.path.join(broken, "templates/main.py")
        with open(spine, encoding="utf-8") as fh:
            body = fh.read()
        with open(spine, "w", encoding="utf-8") as fh:
            fh.write(body.replace("== [1565448431", "== [9999999999"))
        rc_bs, out_bs = sh(["bash", os.path.join(broken, "tools/new-project.sh"),
                            "--no-venv", "x", tmp], env={"PLAYBOOK": broken})

        check("scaffold refuses to pin numbers from a failing spine",
              lambda: rc_bs != 0 and "REFUSING" in out_bs)

    with tempfile.TemporaryDirectory() as tmp:
        os.makedirs(os.path.join(tmp, "taken"))
        rc_e, out_e = sh(["bash", SCAFFOLD, "--no-venv", "taken", tmp])
        check("scaffold refuses a directory that already exists",
              lambda: rc_e != 0 and "REFUSING" in out_e)

        rc_s, out_s = sh(["bash", SCAFFOLD, "--no-venv", "two words", tmp])
        check("scaffold refuses a name with a space",
              lambda: rc_s != 0 and "REFUSING" in out_s)

        # A playbook that is valid EXCEPT for the manifest. Pointing this at
        # an empty directory instead was lucky data: the PLAYBOOK.md guard
        # fired first, so gutting the manifest guard survived the whole suite.
        fake = os.path.join(tmp, "fakebook")
        shutil.copytree(ROOT, fake, ignore=shutil.ignore_patterns(".git"))
        os.remove(os.path.join(fake, "SCAFFOLD_MANIFEST"))
        rc_m, out_m = sh(["bash", SCAFFOLD, "--no-venv", "x", tmp],
                         env={"PLAYBOOK": fake})
        # Assert the EFFECT, not the wording. Checking for the string
        # "SCAFFOLD_MANIFEST" in the output also survived, because the gutted
        # version's grep error names the same file -- lucky vocabulary, one
        # layer under lucky data. What only the guard does is refuse BEFORE
        # creating anything.
        check("scaffold refuses to run without a manifest",
              lambda: rc_m != 0
              and out_m.startswith("REFUSING:")
              and not os.path.exists(os.path.join(tmp, "x")))

    # -- the script must work from wherever the clone actually is ------------
    #
    # CI checks the repo out under the runner's workspace, not ~/playbook. The
    # script defaulted to $HOME/playbook and refused. Run it with no $PLAYBOOK
    # and a $HOME that does not exist: it must still find its own repo.

    with tempfile.TemporaryDirectory() as tmp:
        elsewhere = os.path.join(tmp, "clone-somewhere-else")
        shutil.copytree(ROOT, elsewhere, ignore=shutil.ignore_patterns(".git"))
        rc_w, out_w = sh(["bash", os.path.join(elsewhere, "tools/new-project.sh"),
                          "--no-venv", "proj", tmp], no_playbook=True)

        check("scaffold finds its playbook without being told where it is",
              lambda: rc_w == 0
              and os.path.isfile(os.path.join(tmp, "proj/main.py")))

    # -- --dry-run is the by-hand route, derived not retyped -----------------

    with tempfile.TemporaryDirectory() as tmp:
        rc_d, dry = sh(["bash", SCAFFOLD, "--dry-run", "--no-venv", "demo", tmp])

        check("dry run mentions every manifest destination",
              lambda: rc_d == 0 and all(d in dry for _, d, _ in entries))

        check("dry run creates nothing",
              lambda: os.listdir(tmp) == [])

        check("dry run names every file, never git add -A",
              lambda: "add -A" not in code_only(dry) and "git add '" in dry)

    # -- --files-only, the adoption route ------------------------------------

    with tempfile.TemporaryDirectory() as tmp:
        old = os.path.join(tmp, "oldproject")
        os.makedirs(old)
        for fn, body in (("main.py", "print('mine')\n"),
                         ("README.md", "# mine\n"),
                         ("LICENSE", "mine\n")):
            with open(os.path.join(old, fn), "w", encoding="utf-8") as fh:
                fh.write(body)
        rc_f, out_f = sh(["bash", SCAFFOLD, "--files-only", old])

        check("files-only exits clean",
              lambda: rc_f == 0)

        # The whole point: adopting must never overwrite the work being adopted.
        check("files-only overwrites no existing work",
              lambda: read(os.path.join(old, "main.py")) == "print('mine')\n"
              and read(os.path.join(old, "README.md")) == "# mine\n"
              and read(os.path.join(old, "LICENSE")) == "mine\n")

        check("files-only still delivers the practices and the harness",
              lambda: all(os.path.isfile(os.path.join(old, p)) for p in
                          ("PLAYBOOK.md", "CONTRIBUTING.md", "tools/mutate.sh",
                           "tools/_mutate_apply.py",
                           ".github/workflows/validate.yml")))

        # Adoption needs a .gitignore -- the venv it tells you to create lands
        # in git status otherwise -- but must never replace one you already
        # have. Found by adopting a real project, not by reading the document.
        check("files-only delivers a .gitignore when there is none",
              lambda: os.path.isfile(os.path.join(old, ".gitignore")))

        check("files-only creates no repo and no venv",
              lambda: not os.path.exists(os.path.join(old, ".git"))
              and not os.path.exists(os.path.join(old, ".venv")))

    # -- the mutation harness -------------------------------------------------
    #
    # The verdicts are the product. Assert each one is reachable and that the
    # two fixtures are told APART -- a harness that says the same thing about
    # an honest assertion and a circular one is the thing being replaced.

    with tempfile.TemporaryDirectory() as tmp:
        rc_h, honest = run_harness(
            tmp, FIXTURE_HONEST,
            [("real fault", "n * 37", "n * 38")], "honest")

        check("harness says CAUGHT for an honest assertion",
              lambda: "CAUGHT" in honest and "SURVIVED" not in honest)

        check("harness exits 0 when everything is caught",
              lambda: "SUMMARY_EXIT=0" in honest)

        rc_c, circ = run_harness(
            tmp, FIXTURE_CIRCULAR,
            [("real fault", "n * 37", "n * 38")], "circular")

        check("harness says SURVIVED for a circular assertion",
              lambda: "SURVIVED" in circ)

        # Fork D's teeth: a survivor must fail the run, not just print.
        check("a survivor makes the summary exit non-zero",
              lambda: "SUMMARY_EXIT=0" not in circ)

        rc_n, non = run_harness(
            tmp, FIXTURE_HONEST,
            [("anchor cannot match", "quantum_flux", "warp_core"),
             ("crashing mutant", "import sys", "import sys_nope"),
             ("ambiguous anchor", "seed(a)", "seed(a)")], "nonresults")

        check("harness reports ANCHOR FAILED, not a result",
              lambda: "ANCHOR FAILED" in non)

        # A crash means the suite never ran, so it is not evidence about the
        # assertion. The old harness showed a traceback that read like a catch.
        check("harness reports CRASHED separately from CAUGHT",
              lambda: "CRASHED" in non)

        check("harness never calls a non-result CAUGHT",
              lambda: "CAUGHT" not in non)

        rc_b, broke = run_harness(
            tmp, FIXTURE_BROKEN,
            [("irrelevant", "n * 37", "n * 38")], "broken")

        # Mutating a suite that is already failing produces verdicts that mean
        # nothing. Refuse before, not after.
        check("harness refuses to mutate against a failing baseline",
              lambda: "BASELINE IS NOT CLEAN" in broke)

    # -- the harness must not need bash-only syntax ---------------------------

    # This was a text check for the absence of BASH_SOURCE. Replaced with a
    # behavioural one, run under BOTH shells: source the harness from a
    # directory that has nothing to do with it, with no MUT_HELPER, and see
    # whether it can still find its own helper.
    #
    # THE WORKING DIRECTORY IS THE WHOLE POINT. Running this from the repo root
    # proves nothing -- ./tools/_mutate_apply.py is right there, so the search
    # rescues any broken self-location and the mutant survives. That happened:
    # deleting the zsh branch outright passed a zsh test that ran from ROOT.
    def helper_found_from_far_away(shell):
        tmp = tempfile.mkdtemp()
        try:
            toolcopy = os.path.join(tmp, "somewhere", "tools")
            os.makedirs(toolcopy)
            for f in ("mutate.sh", "_mutate_apply.py"):
                shutil.copy(os.path.join(ROOT, "tools", f),
                            os.path.join(toolcopy, f))
            fixture = os.path.join(tmp, "somewhere", "main.py")
            with open(fixture, "w", encoding="utf-8") as fh:
                fh.write(FIXTURE_HONEST)
            script = "\n".join([
                "export SRC=%s CMD=--selftest WORK=%s/.mw" % (fixture, tmp),
                "export TREE= RUN=",
                ". %s/mutate.sh" % toolcopy,
                'run_mutant "real fault" "n * 37" "n * 38"',
            ])
            env = dict(os.environ)
            env.pop("MUT_HELPER", None)
            p_far = subprocess.run([shell, "-c", script], cwd="/", env=env,
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
            return "CAUGHT" in p_far.stdout and "NO HELPER" not in p_far.stdout
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    check("harness works from any working directory under bash",
          lambda: helper_found_from_far_away("bash"))

    # zsh is the shell actually in use and does not define BASH_SOURCE. Run it
    # for real where zsh exists -- CI installs it. Where it does not, fall back
    # to a parse check: weaker, but not nothing.
    zsh = shutil.which("zsh")
    if zsh:
        check("harness works from any working directory under zsh",
              lambda: helper_found_from_far_away(zsh))
    else:
        rc_z, _ = sh(["bash", "-n", os.path.join(ROOT, "tools/mutate.sh")])
        check("harness parses (zsh absent — CI covers the real run)",
              lambda: rc_z == 0)

    if verbose:
        print("%d assertions, %d failed" % (n, bad))
    return 1 if bad else 0


def main(argv):
    if "--smoke" in argv:
        rc = selftest(verbose=False)
        print("smoke: selftest %s" % ("ok" if rc == 0 else "FAILED"))
        return rc
    return selftest()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
