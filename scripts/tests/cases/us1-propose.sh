#!/usr/bin/env bash
# US1: propose inspects the staged set and returns a compliant proposal (read-only)
# Fake secrets are always built at runtime so this file contains no secret-looking literal.

fake_ghp() { printf 'ghp_%s' "$(printf 'a%.0s' {1..36})"; }

begin "US1 single app scope"
mk_repo
echo "// change" >> apps/idea-collector/backend/main.go
git add apps/idea-collector/backend/main.go
run cw propose --json
assert_code 0 "propose single app"
assert_contains "$OUT" '"status":"ok"' "status ok"
assert_contains "$OUT" '"scope":"idea-collector"' "scope is the app name"
assert_contains "$OUT" '"staged_count":1' "one staged file"

begin "US1 ci-only change omits redundant scope"
mk_repo
echo "# x" >> .github/workflows/on_push.yml
git add .github/workflows/on_push.yml
run cw propose --json --summary "bump node"
assert_contains "$OUT" '"type":"ci"' "type ci"
assert_contains "$OUT" '"scope":null' "scope omitted because it equals the type"
assert_contains "$OUT" '"header":"ci: bump node"' "header without (ci)"
run cw propose --json --type fix --summary "handle secrets"
assert_contains "$OUT" '"header":"fix(ci): handle secrets"' "forced type keeps the scope"

begin "US1 docs, req and infra types"
mk_repo
echo "more" >> docs/a.md; git add docs/a.md
run cw propose --json
assert_contains "$OUT" '"type":"docs"' "docs-only is docs"
git reset -q
echo "more" >> specs/003-x/spec.md; echo "more" >> specs/003-x/checklists/requirements.md
git add specs/003-x/spec.md specs/003-x/checklists/requirements.md
run cw propose --json
assert_contains "$OUT" '"type":"req"' "spec + requirements only is req"
git reset -q
echo "more" >> specs/003-x/plan.md; git add specs/003-x/plan.md
run cw propose --json
assert_contains "$OUT" '"type":"docs"' "plan under specs stays docs"
git reset -q
echo "# tf" >> apps/idea-collector/infra/main.tf; git add apps/idea-collector/infra/main.tf
run cw propose --json
assert_contains "$OUT" '"type":"infra"' "infra-only is infra"
assert_contains "$OUT" '"scope":"idea-collector"' "infra keeps the project scope"

begin "US1 lockfile-only is build(deps)"
mk_repo
echo "lock: 2" > pnpm-lock.yaml; git add pnpm-lock.yaml
run cw propose --json --summary "bump dependencies"
assert_contains "$OUT" '"type":"build"' "lockfile-only type"
assert_contains "$OUT" '"scope":"deps"' "lockfile-only scope"
assert_contains "$OUT" '"header":"build(deps): bump dependencies"' "lockfile header"

begin "US1 nothing staged"
mk_repo
run cw propose
assert_code 2 "nothing staged exits 2"
assert_contains "$ERR" "git add" "staging guidance"
echo "// change" >> apps/idea-collector/backend/main.go
run cw propose --json
assert_code 2 "unstaged-only still exits 2"
assert_contains "$OUT" '"status":"empty"' "empty status"
assert_contains "$OUT" '"unstaged_count":1' "unstaged change reported"
assert_contains "$(git status --porcelain)" " M apps/idea-collector/backend/main.go" "unstaged change untouched"

begin "US1 unstaged work is reported, not touched"
mk_repo
echo "// a" >> apps/idea-collector/backend/main.go; git add apps/idea-collector/backend/main.go
echo "more" >> README.md
run cw propose --json
assert_contains "$OUT" '"unstaged_count":1' "unstaged_count 1"
assert_contains "$OUT" 'unstaged-present' "unstaged-present warning"
assert_contains "$(git status --porcelain)" " M README.md" "README still modified and unstaged"

begin "US1 propose is read-only"
mk_repo
echo "// change" >> apps/idea-collector/backend/main.go; git add apps/idea-collector/backend/main.go
before_log=$(git log --oneline | md5sum); before_idx=$(git diff --cached --name-status | md5sum)
run cw propose --json
assert_eq "$before_log" "$(git log --oneline | md5sum)" "git log unchanged"
assert_eq "$before_idx" "$(git diff --cached --name-status | md5sum)" "index unchanged"

begin "US1 merge in progress"
mk_repo
git switch -q -c other main
echo "other side" > README.md; git commit -q -am "docs: other"
git switch -q feat/test
echo "our side" > README.md; git commit -q -am "docs: ours"
git merge other >/dev/null 2>&1
echo "resolved" > README.md; git add README.md
run cw propose --json
assert_code 0 "propose during merge"
assert_contains "$OUT" '"git_state":"merge"' "git_state merge"
assert_contains "$OUT" 'merge-in-progress' "merge-in-progress warning"
assert_contains "$OUT" "Merge branch 'other'" "MERGE_MSG returned as the message"

begin "US1 large changeset"
mk_repo
mkdir -p apps/idea-collector/backend/gen
for i in $(seq 1 201); do echo "package gen" > "apps/idea-collector/backend/gen/f${i}.go"; done
git add apps/idea-collector/backend/gen
run cw propose --json
assert_contains "$OUT" 'large-changeset' "large-changeset warning"
assert_contains "$OUT" 'apps/idea-collector/backend/gen/f201.go' "every file is still listed"
assert_contains "$OUT" '"staged_count":201' "count is 201"

begin "US1 sensitive path and credential content"
mk_repo
printf 'X=1\n' > .env; git add .env
run cw propose --json
assert_code 3 "staged .env blocks propose"
assert_contains "$OUT" '"status":"blocked"' "blocked status"
assert_contains "$OUT" '"kind":"sensitive-path"' "sensitive-path finding"
run cw propose --json --allow-sensitive .env
assert_code 0 "allowed .env proposes"
assert_contains "$OUT" '"allowed":true' "finding marked allowed"
git reset -q; rm -f .env
printf 'token=%s\n' "$(fake_ghp)" > notes.txt; git add notes.txt
run cw propose --json --allow-sensitive notes.txt
assert_code 3 "credential content is never overridable"
assert_contains "$OUT" '"kind":"secret-pattern"' "secret-pattern finding"
assert_not_contains "$OUT$ERR" "$(fake_ghp)" "matched secret text is never printed"

begin "US1 protected branch"
mk_repo
echo "// change" >> apps/idea-collector/backend/main.go; git add apps/idea-collector/backend/main.go
git switch -q main
run cw propose
assert_code 4 "propose on main exits 4"
assert_contains "$ERR" "git switch -c" "branch guidance"
