#!/usr/bin/env python3
"""PreToolUse hook enforcing branch rules.

1. Block code changes (and commit/push) while on a protected branch (main/master).
2. Block creating branches whose names violate branch_policy.

Agents must ask the user for a compliant branch name, create it, then retry.
"""
import json
import os
import re
import shlex
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import branch_policy  # noqa: E402

PROTECTED = {"main", "master"}

data = json.load(sys.stdin)
tool = data.get("tool_name", "")
args = data.get("tool_input") or {}


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))
    sys.exit(0)


def git(*a):
    r = subprocess.run(["git", *a], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def created_branches(command):
    """Yield branch names created by git switch -c / checkout -b / branch <name>."""
    for seg in re.split(r"&&|\|\||;|\|", command):
        try:
            t = shlex.split(seg)
        except ValueError:
            continue
        if len(t) < 3 or t[0] != "git":
            continue
        sub, rest = t[1], t[2:]
        if sub in ("switch", "checkout"):
            flags = {"switch": ("-c", "-C", "--create", "--force-create"),
                     "checkout": ("-b", "-B")}[sub]
            for i, a in enumerate(rest):
                if a in flags and i + 1 < len(rest):
                    yield rest[i + 1]
        elif sub == "branch":
            if any(a.startswith("-") and a not in ("-f", "--force", "-q", "-t", "--track", "--no-track") for a in rest):
                continue  # delete/rename/list/etc.
            pos = [a for a in rest if not a.startswith("-")]
            if pos:
                yield pos[0]


if tool == "Bash":
    for name in created_branches(args.get("command", "")):
        err = branch_policy.check(name)
        if err:
            deny(f"{err} {branch_policy.RULES} Use AskUserQuestion to ask the user for a compliant branch name, then retry.")

root = git("rev-parse", "--show-toplevel")
branch = git("branch", "--show-current")
if not root or branch not in PROTECTED:
    sys.exit(0)

if tool in ("Write", "Edit", "NotebookEdit"):
    path = args.get("file_path") or args.get("notebook_path") or ""
    # Only guard files inside this repo (scratchpad, memory, etc. are fine)
    if not path.startswith(root + "/"):
        sys.exit(0)
elif tool == "Bash":
    # Guard commits and pushes made directly from the protected branch
    if not re.search(r"(^|[;&|\s])git\s+(commit|push)\b", args.get("command", "")):
        sys.exit(0)
else:
    sys.exit(0)

deny(
    f"Branch '{branch}' is protected: changes must not be made on it. "
    "Use AskUserQuestion to ask the user for a branch name following these rules: "
    f"{branch_policy.RULES} Then run 'git switch -c <name>' "
    "(uncommitted changes carry over) and retry."
)
