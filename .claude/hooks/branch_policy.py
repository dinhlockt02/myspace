#!/usr/bin/env python3
"""Branch naming policy shared by the PreToolUse hook and the speckit skills.

CLI: branch_policy.py <name>  -> exit 0 if valid, else print the reason and exit 1.
"""
import re
import sys

TYPES = "feat|fix|chore|docs|refactor|test|ci|infra|req"
RESERVED = {"main", "master", "develop", "head"}
SLUG = r"[a-z0-9]+(?:-[a-z0-9]+)*"
TYPED = re.compile(rf"^(?:{TYPES})/(?:{SLUG}/)?({SLUG})$")
SPECKIT = re.compile(rf"^(?:\d{{3}}|\d{{8}}-\d{{6}})-({SLUG})$")

RULES = (
    "Allowed formats: '<type>/<description>' or '<type>/<scope>/<description>' "
    f"(type: {TYPES.replace('|', ', ')}; scope optional, e.g. idea-collector, infra, shared, ci), "
    "or the Spec Kit form 'NNN-<description>'. Description and scope are lowercase "
    "kebab-case ([a-z0-9-]), description 3-50 chars. "
    "Reserved: main, master, develop, HEAD, release/*."
)


def check(name: str):
    """Return None if valid, else a human-readable reason."""
    if name.lower() in RESERVED or name.lower().startswith("release/"):
        return f"'{name}' is a reserved branch name."
    m = TYPED.match(name) or SPECKIT.match(name)
    if not m:
        return f"'{name}' does not match the branch naming rules."
    if not 3 <= len(m.group(1)) <= 50:
        return f"'{name}': description must be 3-50 characters."
    return None


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: branch_policy.py <branch-name>")
    err = check(sys.argv[1])
    if err:
        print(f"{err} {RULES}")
        sys.exit(1)
