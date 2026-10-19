#!/usr/bin/env bash
# US4: validate reports every mechanically checkable defect with a suggestion; it never touches git

rep() { printf "$1%.0s" $(seq 1 "$2"); }

begin "US4 an invalid message reports errors and a warning together"
mk_repo
run cw validate "Fixed the Thing." --json
assert_code 1 "invalid message exits 1"
assert_contains "$OUT" '"valid":false' "valid false"
assert_contains "$OUT" '"rule":"type-invalid","severity":"error"' "type-invalid is an error"
assert_contains "$OUT" '"rule":"uppercase-summary","severity":"error"' "uppercase-summary is an error"
assert_contains "$OUT" '"rule":"trailing-period","severity":"error"' "trailing-period is an error"
assert_contains "$OUT" '"rule":"not-imperative","severity":"warning"' "not-imperative is a warning"
assert_contains "$OUT" '"suggestion":"' "suggestions are provided"

begin "US4 a warning alone does not fail validation or block a commit"
mk_repo
run cw validate "fix(ci): added secret" --json
assert_code 0 "warning-only message exits 0"
assert_contains "$OUT" '"valid":true' "valid true"
assert_contains "$OUT" '"rule":"not-imperative","severity":"warning"' "warning listed"
echo "# x" >> .github/workflows/on_push.yml; git add .github/workflows/on_push.yml
run cw commit --message "fix(ci): added secret" --yes --json
assert_code 0 "commit succeeds with a warning"
assert_contains "$OUT" '"validation_warnings":[{"rule":"not-imperative"' "warning returned in validation_warnings"
assert_eq "fix(ci): added secret" "$(git log -1 --format=%s)" "commit created"

begin "US4 valid messages"
mk_repo
for m in "fix(idea-collector): handle empty claims" "feat: add thing" "req: add new requirements" \
         "infra(idea-collector): add cognito client" "build(deps): bump dependencies" "docs!: drop old guide"$'\n\nBREAKING CHANGE: guide removed'; do
    run cw validate "$m"
    assert_code 0 "valid: ${m%%$'\n'*}"
done
run cw validate "feature: add thing"
assert_code 1 "feature is not a type"
run cw validate "fix(Bad_Scope): x"
assert_code 1 "invalid scope"

begin "US4 header length is strictly under 100"
mk_repo
h99="feat: $(rep a 93)"; h100="feat: $(rep a 94)"
assert_eq 99 "${#h99}" "fixture is 99 characters"
run cw validate "$h99"
assert_code 0 "99 characters pass"
run cw validate "$h100" --json
assert_code 1 "100 characters fail"
assert_contains "$OUT" 'header-too-long' "header-too-long reported"

begin "US4 blank line between header and body"
mk_repo
run cw validate $'fix: handle input\nbody starts here' --json
assert_code 1 "missing blank line"
assert_contains "$OUT" 'missing-blank-line' "rule reported"
run cw validate $'fix: handle input\n\nbody starts here'
assert_code 0 "blank line present"

begin "US4 breaking footer must match the bang"
mk_repo
run cw validate "fix!: drop endpoint" --json
assert_code 1 "bang without footer"
assert_contains "$OUT" 'breaking-footer-missing' "reported"
run cw validate $'fix: drop endpoint\n\nBREAKING CHANGE: gone' --json
assert_code 1 "footer without bang"
assert_contains "$OUT" 'breaking-footer-missing' "reported both directions"

begin "US4 footer format"
mk_repo
run cw validate $'fix: handle input\n\nCo-Authored-By: A <a@b.c>\nnot a trailer' --json
assert_code 1 "malformed footer line"
assert_contains "$OUT" 'footer-format' "reported"
run cw validate $'fix: handle input\n\nCo-Authored-By: A <a@b.c>'
assert_code 0 "well-formed footer"

begin "US4 imperative allowlist and third-person verbs"
mk_repo
run cw validate "fix: add embed speed" --json
assert_not_contains "$OUT" 'not-imperative' "allowlisted words are fine"
run cw validate "feat: adds thing" --json
assert_contains "$OUT" 'not-imperative' "third-person verb warns"
assert_code 0 "still valid"
run cw validate "fix: handling empty input" --json
assert_contains "$OUT" 'not-imperative' "gerund warns"

begin "US4 git-generated merge messages"
mk_repo
run cw validate "Merge branch 'x'"
assert_code 1 "rejected in a normal state"
git switch -q -c other main
echo "other" > README.md; git commit -q -am "docs: other"
git switch -q feat/test
echo "ours" > README.md; git commit -q -am "docs: ours"
git merge other >/dev/null 2>&1
run cw validate "Merge branch 'other'"
assert_code 0 "accepted during a merge"
run cw validate "fixup! fix: something"
assert_code 0 "fixup accepted during a merge"
git merge --abort >/dev/null 2>&1

begin "US4 input forms and no side effects"
mk_repo
printf 'fix: from file\n' > /tmp/cw-msg.$$
run cw validate --file /tmp/cw-msg.$$
assert_code 0 "--file"
rm -f /tmp/cw-msg.$$
OUT=$(printf 'fix: from stdin\n' | bash "$CW" validate - 2>/dev/null); CODE=$?
assert_code 0 "stdin"
OUT=$(printf 'Bad one.\n' | bash "$CW" validate - 2>/dev/null); CODE=$?
assert_code 1 "stdin invalid"
run cw validate
assert_code 64 "no message is a usage error"
before=$(git status --porcelain | md5sum); log=$(git log --oneline | md5sum)
run cw validate "fix: nothing changes"
assert_eq "$before" "$(git status --porcelain | md5sum)" "status unchanged"
assert_eq "$log" "$(git log --oneline | md5sum)" "history unchanged"
cd / || exit 1
run cw validate "fix: works outside a repository"
assert_code 0 "validate works outside a git repository"
