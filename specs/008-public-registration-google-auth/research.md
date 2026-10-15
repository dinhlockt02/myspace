# Research & Architectural Decisions: Public User Registration with AWS Cognito & Google Auth

## Context & Objectives

The goal is to transition the Idea Collector application from an invite-only model to open public self-registration via a prominent "Sign in with Google" button, while leveraging AWS Cognito User Pool as the central user directory for user profile storage and token issuance.

---

## 1. Central Identity Store & Federation Broker

### Decision
Deploy an **AWS Cognito User Pool** with Google configured as a federated **Social Identity Provider (IdP)** via OpenID Connect (OIDC).

### Rationale
- **Native AWS Integration**: Seamlessly integrates with API Gateway HTTP API v2 and DynamoDB without third-party SaaS identity brokers.
- **Just-In-Time (JIT) Provisioning**: When a user authenticates with Google for the first time, Cognito automatically provisions a `User Account` record in the User Pool, mapping Google claims (`email`, `name`, `sub`) to standard Cognito attributes.
- **Zero Credential Storage**: Complies 100% with Monorepo Constitution Principle IV (Strict Security & Credential Handling). No passwords or user credentials are stored or transmitted by the application.
- **Replaces Custom User & Session Tables**: Eliminates the operational overhead of managing `IdeaCollector_Users` and `IdeaCollector_Sessions` tables in DynamoDB.

### Alternatives Considered
- **Direct Google OAuth + Custom DynamoDB User Store**: Used in milestone 002. Required bespoke Go verification routines, custom token generation, and manual invitation check logic. Deprecated in favor of managed Cognito identity directory.
- **Third-Party Identity Providers (Auth0, Firebase)**: Introduces external vendor dependencies, out-of-band credential configuration, and non-Terraform managed cloud resources.

---

## 2. Authentication Flow & Frontend Integration

### Decision
Implement **OAuth2 Authorization Code Grant with PKCE** (Proof Key for Code Exchange) using direct identity provider routing to Google.

### Rationale
- **Single-Click User Experience**: Initiating authentication via `https://<cognito-domain>/oauth2/authorize?response_type=code&client_id=<client_id>&redirect_uri=<callback>&identity_provider=Google&code_challenge=<challenge>&code_challenge_method=S256` bypasses the default Cognito hosted UI login screen and routes the user directly to Google's authentication prompt.
- **SPA Security Best Practice**: PKCE (RFC 7636) prevents authorization code interception attacks in public Single Page Applications (React 19) without requiring a client secret.
- **Frictionless Onboarding**: Direct entry to the user workspace upon return; frontend exchanges code for Cognito tokens (ID token and Access token) at the Cognito `/oauth2/token` endpoint.

### Alternatives Considered
- **Default Cognito Hosted UI**: Displays Cognito's standard login page with email/password fields and a Google button at the bottom. Rejected because it introduces unnecessary visual friction and contradicts the requirement for a direct "Sign in with Google" button experience.
- **OAuth Implicit Grant**: Tokens exposed in URL fragment hashes; deprecated by OAuth 2.1 and current security standards.
- **AWS Amplify Library (`aws-amplify`)**: Heavy SDK (~500KB+ bundle impact). Implementing native browser `crypto.subtle` for PKCE and standard fetch for token exchange keeps the frontend bundle lean and fast.

---

## 3. API Authorization & Token Verification

### Decision
Configure **AWS API Gateway HTTP API (v2) Native JWT Authorizer** targeting the Cognito User Pool.

### Rationale
- **Edge Validation**: API Gateway validates token signature (Cognito JWKS), expiration, and audience before the request ever reaches the Go Lambda backend.
- **Cost & Latency Optimization**: Unauthorized or expired requests receive an immediate HTTP 401 at the API Gateway layer without invoking Lambda compute.
- **Clean Context Passing**: The validated Cognito user ID is automatically populated in `$context.authorizer.jwt.claims.sub` and email in `$context.authorizer.jwt.claims.email`, eliminating manual token parsing in backend handlers.

### Alternatives Considered
- **Lambda Request Authorizer**: Higher latency and cold-start overhead per request.
- **In-Handler Verification in Go**: Re-parses and validates JWTs inside the Go application logic on every invocation; redundant when HTTP API v2 provides native JWT verification at zero additional cost.

---

## 4. Decommissioning Invitation Architecture

### Decision
Retire the `POST /api/invitations` endpoint, remove `InviteForm.tsx` from the frontend workspace, and remove authorization gates checking for invited status.

### Rationale
- **Requirements Alignment**: Clarification session confirmed that public self-registration replaces the invitation model entirely.
- **Codebase Cleanliness**: Removes unused endpoints, models, handlers, and unit test suites, keeping the codebase focused and maintainable.
- **User Experience**: Simplifies the workspace UI by dedicating the header exclusively to user profile display and logout.

### Alternatives Considered
- **Keeping Invitations as an "Invite a Friend" Referral Feature**: Evaluated during clarification and explicitly rejected by stakeholder choice in favor of simple URL sharing.

---

## 5. Data Isolation & Historical Compatibility

### Decision
Ensure that `user_id` used for idea isolation in DynamoDB `IdeaCollector_Ideas` is consistently mapped from the authenticated token claims.

### Rationale
- `IdeaCollector_Ideas` uses `user_id` as the partition key for the `UserIdeasIndex` GSI.
- For newly self-registered users, `user_id` is the Cognito unique subject identifier (`sub`).
- For backward compatibility with existing users from milestone 002, if historical records were partitioned by email or previous ID, the backend maps the authenticated user claims seamlessly, guaranteeing zero data loss (SC-005).

---

## Summary of Architectural Changes

| Component | Previous Architecture (002) | New Architecture (008) |
| :--- | :--- | :--- |
| **User Directory** | DynamoDB table `IdeaCollector_Users` | AWS Cognito User Pool |
| **Authentication Flow** | Google Sign-In SDK verifying tokens in Go | OAuth2 Authorization Code + PKCE via Cognito Google IdP |
| **Session Management** | DynamoDB table `IdeaCollector_Sessions` (TTL) | Cognito JWT Tokens (Access/ID Tokens) with 1h expiry |
| **API Authorization** | Custom header session check in Go Lambda | API Gateway HTTP API v2 Native JWT Authorizer |
| **Access Model** | Invite-Only (enforced in `auth.go`) | Open Public Self-Registration (no invite required) |
| **Invitations** | `InviteForm.tsx` & `POST /api/invitations` | Decommissioned and completely removed |
