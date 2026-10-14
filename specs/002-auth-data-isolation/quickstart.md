# Quickstart: Validation Guide for Authentication, Data Isolation & Invitations

This guide describes how to validate the end-to-end functionality of user authentication, strict data isolation, and user invitations across the Idea Collector platform.

## Prerequisites

- DynamoDB tables deployed: `IdeaCollector_Users`, `IdeaCollector_Sessions`, `IdeaCollector_Ideas` (with `UserIdeasIndex` GSI).
- Backend Lambda updated with Google ID token verification, session middleware, and invitation handler.
- Environment variables configured:
  - Backend: `TABLE_NAME=IdeaCollector_Ideas`, `USERS_TABLE_NAME=IdeaCollector_Users`, `SESSIONS_TABLE_NAME=IdeaCollector_Sessions`, `GOOGLE_CLIENT_ID=<client_id>`.
  - Frontend: `VITE_API_URL=https://idea.dinhloc.dev`, `VITE_GOOGLE_CLIENT_ID=<client_id>`.

---

## Scenario 1: Provision Seed User Accounts

Provision two test accounts into `IdeaCollector_Users` to seed initial access: User A (Alice) and User B (Bob).

```bash
# Provision Alice
aws dynamodb put-item \
  --table-name IdeaCollector_Users \
  --item '{
    "email": {"S": "alice@example.com"},
    "id": {"S": "11111111-1111-4111-8111-111111111111"},
    "status": {"S": "invited"},
    "created_at": {"N": "1696200000000"}
  }'

# Provision Bob
aws dynamodb put-item \
  --table-name IdeaCollector_Users \
  --item '{
    "email": {"S": "bob@example.com"},
    "id": {"S": "22222222-2222-4222-8222-222222222222"},
    "status": {"S": "invited"},
    "created_at": {"N": "1696200000000"}
  }'
```

*Expected Outcome*: Both records are inserted into `IdeaCollector_Users` with status `invited`.

---

## Scenario 2: Validate Uninvited Google SSO Access Rejection

Attempt to authenticate using a valid Google ID token for an uninvited email address (`mallory@example.com`).

```bash
curl -X POST https://idea.dinhloc.dev/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{"id_token": "<google_id_token_for_uninvited_account>"}'
```

*Expected Outcome*:
- HTTP Status: `403 Forbidden`
- Response Body:
  ```json
  {
    "error": "ACCOUNT_NOT_INVITED",
    "message": "Account not authorized. An administrative invitation is required."
  }
  ```
- No session is created in `IdeaCollector_Sessions`.

---

## Scenario 3: Validate Invited User Authentication & Session Establishment

Authenticate with a valid Google ID token for provisioned user Alice (`alice@example.com`).

```bash
curl -X POST https://idea.dinhloc.dev/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{"id_token": "<google_id_token_for_alice>"}'
```

*Expected Outcome*:
- HTTP Status: `200 OK`
- Response Body contains `session_token`, `expires_in: 3600`, and user DTO matching Alice's UUID (`11111111-1111-4111-8111-111111111111`).
- `IdeaCollector_Users` item for Alice transitions status from `invited` to `active` with `google_sub` and `last_login_at` recorded.
- Session record is stored in `IdeaCollector_Sessions`.

---

## Scenario 4: Submit Idea & Verify User-Isolated Listing

Using Alice's session token (`SESSION_A`), submit a new idea and query Alice's idea list.

1. **Submit Idea:**
   ```bash
   curl -X POST https://idea.dinhloc.dev/api/ideas \
     -H "Authorization: Bearer <SESSION_A>" \
     -H "Content-Type: application/json" \
     -d '{"idea": "Alice first innovative idea", "timestamp": 1696200010000}'
   ```
   *Expected Outcome*: HTTP `201 Created` with generated idea `id`. Idea is stored with `user_id = 11111111-1111-4111-8111-111111111111`.

2. **Retrieve Alice's Ideas:**
   ```bash
   curl -X GET https://idea.dinhloc.dev/api/ideas \
     -H "Authorization: Bearer <SESSION_A>"
   ```
   *Expected Outcome*: HTTP `200 OK`. The returned list includes Alice's idea.

---

## Scenario 5: Cross-User Data Access Isolation (User A vs User B)

Log in as Bob (`bob@example.com`) to obtain `SESSION_B`, and verify Bob cannot see Alice's ideas.

1. **Submit Bob's Idea:**
   ```bash
   curl -X POST https://idea.dinhloc.dev/api/ideas \
     -H "Authorization: Bearer <SESSION_B>" \
     -H "Content-Type: application/json" \
     -d '{"idea": "Bob proprietary project idea", "timestamp": 1696200020000}'
   ```

2. **Retrieve Bob's Ideas:**
   ```bash
   curl -X GET https://idea.dinhloc.dev/api/ideas \
     -H "Authorization: Bearer <SESSION_B>"
   ```
   *Expected Outcome*:
   - HTTP `200 OK`.
   - The returned array contains *only* Bob's idea ("Bob proprietary project idea").
   - Alice's idea is completely absent (100% data isolation guaranteed via `UserIdeasIndex` query).

3. **Verify Unauthenticated Access Block:**
   ```bash
   curl -X GET https://idea.dinhloc.dev/api/ideas
   ```
   *Expected Outcome*: HTTP `401 Unauthorized`. Unauthenticated access is strictly blocked.

---

## Scenario 6: Validate Session Idle Timeout & Draft Preservation

1. **Simulate 1-Hour Idle Expiration:**
   Update Alice's session record in DynamoDB to simulate >3600 seconds of inactivity:
   ```bash
   aws dynamodb update-item \
     --table-name IdeaCollector_Sessions \
     --key '{"session_id": {"S": "<SESSION_A>"}}' \
     --update-expression "SET last_activity_at = :old" \
     --expression-attribute-values '{":old": {"N": "1696190000000"}}'
   ```

2. **Attempt Request with Expired Session:**
   ```bash
   curl -X GET https://idea.dinhloc.dev/api/ideas \
     -H "Authorization: Bearer <SESSION_A>"
   ```
   *Expected Outcome*: HTTP `401 Unauthorized` with `error: "SESSION_EXPIRED"`.

3. **Validate Frontend Draft Preservation:**
   - Type an idea in the frontend text area ("Unsaved breakthrough thought").
   - Trigger the session expiration.
   - The frontend prompts the user to re-authenticate with Google SSO.
   - The text area retains "Unsaved breakthrough thought" from `localStorage`.
   - Upon re-authenticating, clicking "Submit Idea" succeeds immediately.

---

## Scenario 7: Validate Session Termination via Logout

Terminate Alice's active session.

1. **Call Logout Endpoint:**
   ```bash
   curl -X POST https://idea.dinhloc.dev/api/auth/logout \
     -H "Authorization: Bearer <NEW_SESSION_A>"
   ```
   *Expected Outcome*: HTTP `200 OK` with `{"success": true, "message": "Logged out successfully."}`.

2. **Verify Session Invalidation:**
   ```bash
   curl -X GET https://idea.dinhloc.dev/api/ideas \
     -H "Authorization: Bearer <NEW_SESSION_A>"
   ```
   *Expected Outcome*: HTTP `401 Unauthorized`. The invalidated session is immediately rejected.

---

## Scenario 8: In-App User Invitation & Edge Cases

Using Alice's session token (`SESSION_A`), invite a new collaborator Charlie (`charlie@example.com`).

1. **Send Valid Invitation:**
   ```bash
   curl -X POST https://idea.dinhloc.dev/api/invitations \
     -H "Authorization: Bearer <SESSION_A>" \
     -H "Content-Type: application/json" \
     -d '{"email": "charlie@example.com"}'
   ```
   *Expected Outcome*: HTTP `201 Created` with `{"success": true, "message": "Invitation created successfully.", "email": "charlie@example.com"}`. An item is created in `IdeaCollector_Users` with `status: "invited"` and `invited_by_user_id: "11111111-1111-4111-8111-111111111111"`.

2. **Attempt Duplicate Invitation:**
   ```bash
   curl -X POST https://idea.dinhloc.dev/api/invitations \
     -H "Authorization: Bearer <SESSION_A>" \
     -H "Content-Type: application/json" \
     -d '{"email": "charlie@example.com"}'
   ```
   *Expected Outcome*: HTTP `409 Conflict` with `message: "The specified email address has already been invited or is active."`.

3. **Attempt Self-Invitation:**
   ```bash
   curl -X POST https://idea.dinhloc.dev/api/invitations \
     -H "Authorization: Bearer <SESSION_A>" \
     -H "Content-Type: application/json" \
     -d '{"email": "alice@example.com"}'
   ```
   *Expected Outcome*: HTTP `400 Bad Request` with validation error indicating self-invitation is disallowed.

4. **Authenticate as Newly Invited User (Charlie):**
   ```bash
   curl -X POST https://idea.dinhloc.dev/api/auth/google \
     -H "Content-Type: application/json" \
     -d '{"id_token": "<google_id_token_for_charlie>"}'
   ```
   *Expected Outcome*: HTTP `200 OK`. Charlie is successfully authenticated and receives an active session token. Accessing `GET /api/ideas` returns an empty collection ready for Charlie's first idea.
