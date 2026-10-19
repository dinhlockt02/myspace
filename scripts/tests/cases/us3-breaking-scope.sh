#!/usr/bin/env bash
# US3: explicit breaking-change decisions and multi-scope warnings

begin "US3 backend deletion needs a breaking decision"
mk_repo
git rm -q apps/idea-collector/backend/handlers/auth.go
run cw propose --json
assert_contains "$OUT" 'removed or renamed file in a public area' "deletion raises a breaking hint"
run cw commit --message "refactor(idea-collector): remove google token handler" --yes
assert_code 6 "no decision exits 6"
assert_eq "chore: initial" "$(git log -1 --format=%s)" "no commit without a decision"
run cw commit --message "refactor(idea-collector): remove google token handler" --yes --breaking "POST /api/auth/google is gone"
assert_code 0 "--breaking commits"
body=$(git log -1 --format=%B)
assert_contains "$body" "refactor(idea-collector)!: remove google token handler" "header gains !"
assert_contains "$body" $'\n\nBREAKING CHANGE: POST /api/auth/google is gone' "BREAKING CHANGE footer after a blank line"

begin "US3 --no-breaking confirms the change is not breaking"
mk_repo
git rm -q apps/idea-collector/backend/handlers/auth.go
run cw commit --message "refactor(idea-collector): remove unused handler" --yes --no-breaking
assert_code 0 "--no-breaking commits"
assert_eq "refactor(idea-collector): remove unused handler" "$(git log -1 --format=%s)" "header has no !"
assert_not_contains "$(git log -1 --format=%B)" "BREAKING CHANGE" "no footer"

begin "US3 a header with ! and a footer already decides"
mk_repo
git rm -q apps/idea-collector/backend/handlers/auth.go
run cw commit --message $'refactor(idea-collector)!: remove handler\n\nBREAKING CHANGE: gone' --yes
assert_code 0 "message that already declares the break commits"

begin "US3 --breaking is not duplicated"
mk_repo
git rm -q apps/idea-collector/backend/handlers/auth.go
run cw commit --message $'refactor(idea-collector)!: remove handler\n\nBREAKING CHANGE: gone' --yes --breaking "gone"
assert_code 0 "commit"
assert_eq "1" "$(git log -1 --format=%B | grep -c '^BREAKING CHANGE:')" "exactly one footer"

begin "US3 Terraform variable removal and exported symbol removal raise hints"
mk_repo
printf 'variable "a" {}\nvariable "b" {}\n' > apps/idea-collector/infra/main.tf
printf 'package handlers\nfunc Exported() {}\n' > apps/idea-collector/backend/handlers/auth.go
git add -A; git commit -q -m "chore: seed"
printf 'variable "b" {}\n' > apps/idea-collector/infra/main.tf
git add apps/idea-collector/infra/main.tf
run cw propose --json
assert_contains "$OUT" 'Terraform variable/output' "removed variable raises a hint"
git reset -q
printf 'package handlers\n' > apps/idea-collector/backend/handlers/auth.go
git add apps/idea-collector/backend/handlers/auth.go
run cw propose --json
assert_contains "$OUT" 'exported symbol' "removed exported symbol raises a hint"

begin "US3 a safe change raises no hint"
mk_repo
echo "// ok" >> apps/idea-collector/backend/main.go; git add apps/idea-collector/backend/main.go
run cw propose --json
assert_contains "$OUT" '"breaking_hints":[]' "no hints"
run cw commit --message "fix(idea-collector): tidy main" --yes
assert_code 0 "commits without a decision"

begin "US3 multi-scope changeset gets a split suggestion"
mk_repo
echo x > apps/commifra/x.txt; echo y > apps/idea-collector/y.txt
git add apps/commifra/x.txt apps/idea-collector/y.txt
before_idx=$(git diff --cached --name-status | md5sum)
run cw propose --json
assert_code 0 "multi-scope is a warning, not a block"
assert_contains "$OUT" 'multi-scope' "multi-scope warning"
assert_contains "$OUT" '"split_suggestion":[{"scope":"commifra"' "commifra group"
assert_contains "$OUT" '"scope":"idea-collector","files":["apps/idea-collector/y.txt"]' "idea-collector group"
assert_contains "$OUT" '"scope":null' "no single scope is proposed"
assert_eq "$before_idx" "$(git diff --cached --name-status | md5sum)" "propose never unstages"
assert_contains "$ERR" "git restore --staged" "split command is suggested as text"

begin "US3 companion files do not trigger multi-scope"
mk_repo
echo "// ok" >> apps/idea-collector/backend/main.go
echo "lock: 2" > pnpm-lock.yaml
echo "# note" >> specs/003-x/plan.md
git add apps/idea-collector/backend/main.go pnpm-lock.yaml specs/003-x/plan.md
run cw propose --json
assert_not_contains "$OUT" 'multi-scope' "lockfile and specs are companions"
assert_contains "$OUT" '"scope":"idea-collector"' "scope follows the main change"
