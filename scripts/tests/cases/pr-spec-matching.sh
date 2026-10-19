#!/usr/bin/env bash
# PR formatter: a branch only gets a spec's intent and task list when it truly belongs to that spec
# (scripts/lib/pr-formatter.sh). Regression tests for the "touches files under specs/NNN" false match.

LIB="$(CDPATH="" cd "${TESTS_DIR}/../lib" && pwd)"

# Run a pr-formatter function inside the current repo in a subshell
pr_fn() { # function-name args...
    (
        REPO_ROOT="$PWD"; BASE_BRANCH=main
        source "$LIB/reporter.sh"; source "$LIB/pr-git.sh"; source "$LIB/pr-formatter.sh"
        "$@"
    ) 2>/dev/null
}

matched_spec() { basename "$(pr_fn detect_active_feature_dir)"; }
pr_body() { pr_fn generate_pr_body "$(git branch --show-current)" main "" ""; }
pr_title() { pr_fn generate_pr_title "$(git branch --show-current)" ""; }

begin "PR spec match: branch number matches the spec"
mk_repo
git switch -q -c feat/003
echo "// x" >> apps/idea-collector/backend/main.go; git commit -q -am "feat: x"
assert_eq "003-x" "$(matched_spec)" "feat/003 belongs to spec 003-x"

begin "PR spec match: editing an existing spec does not claim the feature"
mk_repo
git switch -q -c docs/tidy-plan
echo "more" >> specs/003-x/plan.md; echo "more" >> specs/003-x/spec.md
git commit -q -am "docs: tidy the plan"
assert_eq "" "$(matched_spec)" "a docs-only touch of spec 003-x matches no spec"
body=$(pr_body)
assert_not_contains "$body" "Feature ID" "body has no Feature ID line"
assert_not_contains "$body" "Completed Tasks" "body has no spec task list"
assert_contains "$body" "tidy the plan" "body is built from the commits instead"
assert_eq "docs: tidy the plan" "$(pr_title)" "title comes from the single commit"

begin "PR spec match: a branch that adds the spec owns it"
mk_repo
git switch -q -c feat/new-thing
mkdir -p specs/004-new-thing; echo "# Feature Specification: New Thing" > specs/004-new-thing/spec.md
git add specs/004-new-thing; git commit -q -m "req: add new thing requirements"
assert_eq "004-new-thing" "$(matched_spec)" "adding spec.md makes the branch the feature's"

begin "PR spec match: a stale feature.json is ignored"
mk_repo
mkdir -p .specify; echo '{"feature_directory": "specs/003-x"}' > .specify/feature.json
git switch -q -c fix/scripts/unrelated
echo "// y" >> apps/idea-collector/backend/main.go; git commit -q -am "fix: y"
assert_eq "" "$(matched_spec)" "feature.json alone does not attach a spec"
assert_not_contains "$(pr_body)" "Feature ID" "no spec text in the body"

begin "PR spec match: branch named exactly like the spec"
mk_repo
git switch -q -c 003-x
echo "// z" >> apps/idea-collector/backend/main.go; git commit -q -am "feat: z"
assert_eq "003-x" "$(matched_spec)" "NNN-name branch matches by name"
