# Research & Decisions: User Authentication and Data Isolation

## 1. Google SSO Authentication & Token Verification

**Task**: Research optimal Google SSO integration and token verification pattern for a serverless React frontend and Go Lambda backend.

**Decision**: Use Google Identity Services (GIS) on the frontend to initiate federated sign-in and obtain a Google ID Token (JWT). The frontend submits this token to `POST /api/auth/google`. The Go Lambda backend verifies the cryptographic signature against Google's public JSON Web Key Set (JWKS at `https://www.googleapis.com/oauth2/v3/certs`), validates claims (`iss` in `["accounts.google.com", "https://accounts.google.com"]`, `aud` matching `GOOGLE_CLIENT_ID`, and unexpired `exp`), and extracts the verified email and Google subject identifier (`sub`).

**Rationale**:
- Google ID token (OpenID Connect) provides cryptographically signed assertions of user identity directly to the client without requiring server-side OAuth2 redirect round-trips or client secrets.
- Verifying Google public keys in Go via standard JWKS parsing (cached in memory during Lambda warm runs) has sub-5ms overhead, requires zero third-party auth service fees, and strictly adheres to Constitution Principle IV (no secrets/credentials committed).
- Clean separation between identity provider (Google) and application authorization.

**Alternatives considered**:
- *AWS Cognito User Pool with Google IdP*: Rejected due to high Terraform complexity, Cognito hosted UI redirects, and unnecessary cost/overhead for a lightweight invite-only application.
- *OAuth 2.0 Authorization Code Flow with Client Secret*: Rejected because server-side secrets are unnecessary when OpenID Connect client-side credential verification meets all security and audit needs.
- *Direct Google ID Token on every API request*: Rejected because Google ID tokens have a fixed 1-hour expiration from issuance, cannot support sliding idle timeouts (FR-011), and cannot be immediately revoked on user logout (FR-004).

## 2. Session Lifecycle & 1-Hour Idle Timeout Enforcement

**Task**: Determine the session management architecture to enforce 1-hour idle timeout (FR-011) and immediate logout invalidation (FR-004).

**Decision**: Introduce an `IdeaCollector_Sessions` DynamoDB table. Upon successful Google authentication and invite verification, the backend issues a high-entropy cryptographically secure random session token (`crypto/rand`, 32 bytes base64url). The session record stores `session_id`, `user_id`, `created_at`, `last_activity_at`, `expires_at` (epoch seconds for DynamoDB TTL), and `is_valid`. The token is returned to the client and sent in `Authorization: Bearer <session_token>` for all protected endpoints. On every request:
1. Verify `is_valid == true`.
2. Check `current_time - last_activity_at <= 3600`.
3. If valid, update `last_activity_at = current_time` and `expires_at = current_time + 3600` (sliding 1-hour window).
4. If expired or invalid, return `401 Unauthorized` with error `SESSION_EXPIRED`.
5. On `POST /api/auth/logout`, mark `is_valid = false`.

**Rationale**:
- DynamoDB single-item lookups by `session_id` take 1–3 ms.
- DynamoDB native TTL automatically cleans up expired sessions without cron jobs or background sweeps.
- Sliding idle timeout requires mutable `last_activity_at` state, which is clean and efficient in DynamoDB.
- Immediate logout terminates the session synchronously, fulfilling FR-004 and SC-001.

**Alternatives considered**:
- *Stateless JWT with 1-hour expiration*: Cannot handle sliding idle timeouts (only fixed expiration from issue time) and cannot instantly revoke tokens upon logout without a blacklist store.
- *ElastiCache (Redis)*: Rejected due to AWS infrastructure cost and VPC requirements for Lambda, violating the lightweight serverless monorepo model.

## 3. Invite-Only / Provisioned Users Authorization

**Task**: Design access control to enforce invite-only / admin-provisioned access (FR-001, FR-003).

**Decision**: Introduce an `IdeaCollector_Users` DynamoDB table where the Partition Key is the normalized lowercase `email`. Attributes include `id` (UUID v4), `email` (String), `google_sub` (String, populated on first login), `status` (`invited` | `active` | `suspended`), `invited_by_user_id` (String UUID), `created_at` (Number), and `last_login_at` (Number). When a user authenticates via Google SSO:
1. Look up `IdeaCollector_Users` by the verified Google email.
2. If record does not exist: Reject with `403 Forbidden` (`ACCOUNT_NOT_INVITED`). Do not create account or reveal tenant data.
3. If record exists and `status == "suspended"`: Reject with `403 Forbidden` (`ACCOUNT_SUSPENDED`).
4. If record exists and `status == "invited"`: Update `status = "active"`, save `google_sub`, update `last_login_at`, and create session.
5. If record exists and `status == "active"`: Verify matching `google_sub`, update `last_login_at`, and create session.

**Rationale**:
- Point lookups by email in DynamoDB are deterministic, fast, and prevent self-registration.
- Supports provisioning via Terraform, admin CLI, direct DynamoDB PutItem, or in-app peer invitations.
- Prevents identity spoofing by linking the permanent Google subject ID (`sub`) to the user profile upon first login.

**Alternatives considered**:
- *Environment Variable Whitelist (`ALLOWED_EMAILS`)*: Inflexible, cannot store user metadata/UUIDs, requires redeploying Lambdas to add users.
- *Single-table design combining Users and Ideas*: Adds unnecessary partition overloading and complex indexing for a low-complexity monorepo application.

## 4. Multi-Tenant Data Isolation & Querying

**Task**: Formulate DynamoDB schema and query patterns ensuring strict data isolation (FR-008, FR-009) and reverse-chronological idea listing (FR-010).

**Decision**: Maintain `IdeaCollector_Ideas` table with primary key `id` (UUID). Add a Global Secondary Index (GSI) named `UserIdeasIndex`:
- Partition Key: `user_id` (String)
- Sort Key: `server_timestamp` (Number)
- Projection: `ALL`

When listing ideas (`GET /api/ideas`), backend queries `UserIdeasIndex` using `user_id = session.user_id` with `ScanIndexForward = false` (descending order by timestamp).
When creating an idea (`POST /api/ideas`), backend injects `user_id = session.user_id` from the validated session.
Direct idea access or probing (by `id`) validates that `item.user_id == session.user_id`; any mismatch returns `404 Not Found` (revealing no metadata).

**Rationale**:
- A DynamoDB GSI `Query` by partition key is mathematically scoped to the authenticated user's records only. Zero cross-tenant data leakage is possible.
- `ScanIndexForward = false` provides sorted results at database engine level with zero in-memory sorting.
- DynamoDB GSIs are sparse: existing legacy ideas without a `user_id` attribute will NOT be indexed in `UserIdeasIndex`, automatically isolating legacy data as specified in Edge Cases.

**Alternatives considered**:
- *DynamoDB Scan with FilterExpression*: Expensive, insecure (fetches all tenant records before filtering), and risks data leaks if filter logic fails.
- *Composite Table Key (`user_id` HASH, `id` RANGE)*: Would break existing single-item access and make legacy data handling complex.

## 5. Client Session State & Draft Preservation

**Task**: Design client-side session timeout detection and draft idea preservation (FR-012, User Story 4).

**Decision**: The React frontend synchronizes idea textarea content to `localStorage` under `ideacollector_draft_content`. An API client wrapper intercepts `401 Unauthorized` responses. If a `401` occurs:
1. Mark authentication state as `expired`.
2. Display a non-destructive re-authentication prompt / modal.
3. Keep the current draft in the form textarea and `localStorage`.
4. Upon re-authenticating with Google SSO, the session is refreshed, the modal closes, and the user can click "Submit Idea" without retyping.
5. Upon successful submission, `ideacollector_draft_content` is removed from `localStorage`.

**Rationale**:
- Prevents frustrating data loss during idle timeout (FR-012, SC-007).
- Resilient to accidental page refreshes.

**Alternatives considered**:
- *Memory-only state in React*: Lost if the user reloads the page or navigates away while expired.

## 6. Frontend In-App Invitation Flow & Validation

**Task**: Design the frontend interface, API endpoint, and validation rules for inviting new users (FR-014, FR-015, User Story 5).

**Decision**: Provide an authenticated endpoint `POST /api/invitations` and an "Invite Collaborator" interface in the frontend workspace.
- **Backend Flow**:
  1. Verify caller has an active session (`session.user_id`, `session.email`).
  2. Parse and normalize incoming email to lowercase; validate email syntax against standard email pattern.
  3. Validate caller is not self-inviting (`req.email != session.email`).
  4. Query `IdeaCollector_Users` for `req.email`. If found, return HTTP `409 Conflict` (or informational status indicating account already authorized).
  5. If absent, insert record in `IdeaCollector_Users` with:
     - `email`: normalized lowercase email
     - `id`: generated UUID v4
     - `status`: `"invited"`
     - `invited_by_user_id`: `session.user_id`
     - `created_at`: current epoch milliseconds
  6. Return HTTP `201 Created` with confirmation message.
- **Frontend Flow**:
  - Add an invitation card/modal within the authenticated view allowing the user to enter a Google email and click "Send Invitation".
  - Display immediate feedback: success confirmation on creation, or clear notice if the user is already registered or invalid.

**Rationale**:
- Satisfies the clarified requirement allowing any authenticated member to onboard collaborators seamlessly.
- Directly reuses the `IdeaCollector_Users` table and auth pipeline without additional storage engines.

**Alternatives considered**:
- *Out-of-band email sending via AWS SES*: Deferred; the invitee is immediately authorized and can log in directly using Google SSO, keeping infrastructure lean and avoiding email deliverability dependencies.
