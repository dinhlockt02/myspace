#!/usr/bin/env bash
# US2: commit validates, confirms and commits exactly the staged set
# Fake secrets are always built at runtime so this file contains no secret-looking literal.

rep() { printf "$1%.0s" $(seq 1 "$2"); }   # rep <char> <count>
fake_ghp() { printf 'ghp_%s' "$(rep a 36)"; }

stage_change() { echo "// change $RANDOM" >> apps/idea-collector/backend/main.go; git add apps/idea-collector/backend/main.go; }

begin "US2 confirmation is required when not interactive"
mk_repo
stage_change
before=$(git rev-parse HEAD)
run cw commit --message "fix(idea-collector): handle empty claims"
assert_code 5 "no --yes in a non-TTY exits 5"
assert_eq "$before" "$(git rev-parse HEAD)" "no commit was created"
assert_contains "$(git diff --cached --name-only)" "apps/idea-collector/backend/main.go" "file is still staged"

begin "US2 commit with --yes records the exact message"
mk_repo
stage_change
run cw commit --message "fix(idea-collector): handle empty claims" --yes --json
assert_code 0 "commit succeeds"
assert_eq "fix(idea-collector): handle empty claims" "$(git log -1 --format=%B | sed '/^$/d')" "message is exactly as given"
short=$(git rev-parse --short HEAD)
assert_contains "$OUT" "\"hash\":\"${short}\"" "returned hash matches HEAD"
assert_contains "$OUT" '"status":"committed"' "committed status"
assert_eq "" "$(git diff --cached --name-only)" "nothing left staged"

begin "US2 only the staged set is committed"
mk_repo
stage_change
echo "more" >> README.md
run cw commit --message "fix(idea-collector): handle empty claims" --yes
assert_code 0 "commit with unstaged work present"
assert_contains "$(git status --porcelain)" " M README.md" "unstaged change remains modified"
assert_eq "apps/idea-collector/backend/main.go" "$(git show --name-only --format= HEAD)" "commit contains only the staged file"

begin "US2 invalid and empty messages are rejected"
mk_repo
stage_change
run cw commit --message "" --yes
assert_code 1 "empty message exits 1"
run cw commit --message "   " --yes
assert_code 1 "whitespace-only message exits 1"
run cw commit --message "feature: add thing" --yes --json
assert_code 1 "invalid type exits 1"
assert_contains "$OUT" 'type-invalid' "type-invalid reported"
assert_eq "chore: initial" "$(git log -1 --format=%s)" "no commit was created"

begin "US2 nothing staged"
mk_repo
run cw commit --message "fix: x" --yes
assert_code 2 "nothing staged exits 2"

begin "US2 protected branch"
mk_repo
stage_change
git switch -q main
run cw commit --message "fix(idea-collector): handle empty claims" --yes
assert_code 4 "commit on main exits 4"
assert_eq "chore: initial" "$(git log -1 --format=%s)" "no commit on main"

begin "US2 sensitive path override is per path"
mk_repo
printf 'X=1\n' > .env; git add .env
run cw commit --message "chore: add config" --yes
assert_code 3 "staged .env blocks"
assert_eq "chore: initial" "$(git log -1 --format=%s)" "nothing committed"
run cw commit --message "chore: add config" --yes --allow-sensitive .env
assert_code 0 "--allow-sensitive .env commits"
git reset -q --hard
printf 'token=%s\n' "$(fake_ghp)" > notes.txt; git add notes.txt
run cw commit --message "chore: add notes" --yes --allow-sensitive notes.txt
assert_code 3 "credential content still blocks with the flag"

begin "US2 every credential format blocks without printing it"
declare -A SAMPLES=(
    [aws-access-key-id]="AKIA$(rep A 16)"
    [google-oauth-client-secret]="GOCSPX-$(rep b 28)"
    [slack-token]="xoxb-$(rep 1 12)"
    [github-token]="gho_$(rep c 36)"
    [github-fine-grained-pat]="github_pat_$(rep d 30)"
    [pgp-private-key]="$(printf -- '-----BEGIN %s-----' 'PGP PRIVATE KEY BLOCK')"
)
for rule in "${!SAMPLES[@]}"; do
    mk_repo
    printf 'value: %s\n' "${SAMPLES[$rule]}" > config.txt; git add config.txt
    run cw commit --message "chore: add config" --yes --json
    assert_code 3 "$rule blocks"
    assert_contains "$OUT" "\"rule\":\"${rule}\"" "$rule is named"
    assert_not_contains "$OUT$ERR" "${SAMPLES[$rule]}" "$rule text is never printed"
    assert_eq "chore: initial" "$(git log -1 --format=%s)" "$rule: nothing committed"
done

begin "US2 harmless lines do not block"
mk_repo
printf 'client_secret = var.google_client_secret\nVITE_COGNITO_CLIENT_ID=abc\n' > ok.txt; git add ok.txt
run cw commit --message "chore: add config" --yes
assert_code 0 "references and public ids do not block"

begin "US2 trailers are appended after a blank line"
mk_repo
stage_change
run cw commit --message "fix(idea-collector): handle empty claims" --yes --trailer "Co-Authored-By: A <a@b.c>"
assert_code 0 "commit with trailer"
assert_contains "$(git log -1 --format=%B)" $'handle empty claims\n\nCo-Authored-By: A <a@b.c>' "trailer after a blank line"
mk_repo
stage_change
run cw commit --message "fix(idea-collector): handle empty claims" --yes --trailer "not a trailer"
assert_code 1 "malformed trailer is rejected"
