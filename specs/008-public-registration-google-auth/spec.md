# Feature Specification: Public User Registration and Google Authentication

**Feature Branch**: `008-public-registration-google-auth`

**Created**: 2026-10-15

**Status**: Draft

**Input**: User description: "As user, I want to create account without invitation. Also, I want to login with the \"Sign with Google\" button."

## Clarifications

### Session 2026-10-15

- Q: Now that public self-registration is enabled, how should the existing user invitation system and its frontend UI be handled? → A: Remove the invitation UI and endpoints entirely; users join directly by visiting the site and signing in via Google.
- Q: What onboarding step should occur immediately after a user's first-time Google authentication before entering their workspace? → A: Direct workspace entry; profile name and email are taken directly from Google and the user lands immediately in their empty idea workspace without intermediate setup screens.
- Q: Should public self-registration accept any valid Google account, or should it be restricted to specific email domains? → A: Completely unrestricted; any valid, verified Google account (including consumer @gmail.com and custom Google Workspace domains) can register and log in.
- Q: How should AWS Cognito be integrated to store user information alongside Google authentication? → A: Federated Cognito User Pool; Google is configured as a federated Social Identity Provider in AWS Cognito, which manages OAuth token exchanges, stores and provisions user profile information in the Cognito User Pool, and issues tokens for authenticated sessions.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Public Self-Registration via Google Sign-In (Priority: P1)

A new visitor who has never used the application and does not possess an invitation arrives at the application entry screen. Instead of being blocked by an invite-only barrier or requiring an administrative invitation code, the visitor sees an accessible "Sign in with Google" button. When the visitor clicks the button and completes the authentication prompt with their Google credentials, the system automatically provisions a brand-new user account and directs them immediately into their personal, private workspace ready to capture ideas.

**Why this priority**: Core value of the user request. Eliminating the invite requirement enables open, frictionless onboarding for any prospective user via federated Google identity.

**Independent Test**: Can be tested independently by opening the application in a clean session with a Google account that was never invited or registered, clicking "Sign in with Google", completing the Google consent flow, and verifying that a new user account is successfully provisioned and the user lands in an initialized, private workspace.

**Acceptance Scenarios**:

1. **Given** an unauthenticated visitor without an existing account or invitation, **When** they click "Sign in with Google" and successfully authenticate with their Google account, **Then** the system automatically provisions a new user account and navigates them into their empty personal workspace.
2. **Given** an unauthenticated visitor on the entry screen, **When** they view the screen, **Then** the "Sign in with Google" button is prominently visible and no invitation code or authorization key input is required.
3. **Given** a new user completing registration via Google for the first time, **When** their personal workspace initializes, **Then** a friendly welcome state is presented with guidance on submitting their first idea.

---

### User Story 2 - Returning User Login via Google Sign-In (Priority: P1)

An existing, registered user returns to the application to review their saved ideas or submit new ones. The user navigates to the sign-in page and clicks the "Sign in with Google" button. The system validates the user's identity via Google, identifies the existing account, and restores an active session without creating duplicate account records. The user is brought directly into their existing workspace containing all of their previously authored ideas.

**Why this priority**: Essential for platform continuity. Registered users must be able to log in reliably with the same Google identity to access their stored content.

**Independent Test**: Can be tested independently by logging in as an existing registered user via the "Sign in with Google" button, verifying that authentication completes, and confirming that all previously authored ideas are immediately visible in the workspace.

**Acceptance Scenarios**:

1. **Given** a returning user with an existing registered account, **When** they click "Sign in with Google" and authenticate, **Then** the system establishes an authenticated session and loads their personal workspace with their previously submitted ideas.
2. **Given** an authenticated user in their personal workspace, **When** they choose to log out, **Then** their active session is terminated, and access to protected workspace views requires signing in again.

---

### User Story 3 - Backward Compatibility for Invited and Pre-Existing Accounts (Priority: P2)

Users who joined under previous invite-only versions of the application continue to access their existing accounts and data. When an existing invited user clicks the "Sign in with Google" button using their previously invited Google email address, the system links seamlessly to their existing account profile, preserves all historical ideas, and avoids creating duplicate account entries.

**Why this priority**: Protects existing user trust and historical data during the transition from an invite-only model to public self-registration.

**Independent Test**: Can be tested independently by logging in with a Google account that was originally provisioned via the previous invitation system, verifying successful sign-in, and confirming that all prior ideas and account metadata are intact.

**Acceptance Scenarios**:

1. **Given** a user account created during earlier invite-only releases, **When** the user signs in with that same Google account via the "Sign in with Google" button, **Then** the system recognizes the existing account record without generating a duplicate profile and displays all historical ideas.
2. **Given** an existing invited account that had not yet logged in for the first time, **When** the user logs in via Google SSO, **Then** the account is activated and transitions smoothly to active status without requiring re-invitation.

---

### User Story 4 - Data Isolation and Privacy for Self-Registered Users (Priority: P2)

Multiple independent users register publicly through the "Sign in with Google" flow. The system strictly isolates each user's ideas and data, ensuring that no user can view, query, or infer data belonging to another user. An unauthenticated visitor is completely barred from accessing any protected user ideas or personal workspaces.

**Why this priority**: Public registration exposes the application to arbitrary users; robust multi-tenant data isolation is critical to protecting user privacy and maintaining data security guarantees.

**Independent Test**: Can be tested independently by registering two distinct Google accounts (User A and User B), submitting ideas under each account, and verifying that User A sees only User A's ideas while User B sees only User B's ideas, with direct identifier lookups for User A's ideas returning access denial for User B.

**Acceptance Scenarios**:

1. **Given** two distinct self-registered users (User A and User B), **When** User A logs into their workspace, **Then** only ideas authored by User A are displayed, and no ideas authored by User B are visible.
2. **Given** User B attempts to view or query an idea identifier authored by User A, **When** the system evaluates the request, **Then** access is denied without disclosing any metadata regarding the existence of User A's idea.
3. **Given** an unauthenticated visitor, **When** they attempt to directly navigate to protected workspace views or submit idea data, **Then** the system denies access and redirects the visitor to the Google sign-in prompt.

---

### Edge Cases

- **Canceled or Dismissed Google Authentication**: If the user closes the Google login popup or clicks cancel during the Google consent screen, the application remains on the sign-in screen, displays a clear informational status message, and allows the user to retry without application errors.
- **Google Account Without Verified Email**: If a user attempts to authenticate with a Google account that does not have a verified email address, the system denies account creation with a clear explanatory notice requiring email verification.
- **Account Email Matching Pre-Existing Account**: When a user signs in with a Google identity whose verified email matches an existing registered or invited account, the system resolves the session to the existing account rather than generating an orphaned or duplicate user record.
- **Concurrent First-Time Sign-Ins with the Same Identity**: If rapid concurrent authentication requests arrive for the same Google user identifier (e.g., across multiple browser tabs), the system synchronizes account creation to ensure exactly one unique user account is provisioned without race-condition duplicates.
- **Network Outage or Federated Service Downtime**: If the Google identity service is temporarily unavailable or returns server errors during the authentication attempt, the user is presented with a non-technical error notification advising them to retry momentarily.
- **Session Idle Expiration During Workspace Activity**: If an authenticated session expires after 1 hour of idle inactivity while the user has unsubmitted text in the idea creation field, the system prompts the user to re-authenticate with Google while locally preserving their entered text to prevent work loss.
- **Suspended or Deactivated Accounts**: If a previously registered account has been suspended or deactivated for administrative or security reasons, subsequent sign-in attempts using that Google identity are rejected with an account suspension notice.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST permit public self-registration, allowing any visitor to create an account without requiring an invitation, invite code, or administrative pre-approval.
- **FR-002**: System MUST provide a prominent, accessible "Sign in with Google" button on public landing and authentication screens.
- **FR-003**: System MUST authenticate users via federated Google Single Sign-On (SSO) integrated through an AWS Cognito User Pool, validating identity assertions directly with Google.
- **FR-004**: System MUST automatically provision a new user account upon successful first-time Google sign-in (Just-In-Time provisioning).
- **FR-005**: System MUST associate each provisioned user account with the verified Google identity subject identifier and verified email address.
- **FR-006**: System MUST authenticate returning users with existing accounts upon Google sign-in, seamlessly resuming their active session and personal workspace.
- **FR-007**: System MUST preserve existing accounts and historical ideas created under earlier invite-only versions, enabling those users to sign in with their existing Google account without data duplication or loss.
- **FR-008**: System MUST strictly isolate user data, ensuring each user can only view, create, and manage ideas associated with their own user account.
- **FR-009**: System MUST prevent cross-user data leakage, denying any access requests targeting ideas owned by other user accounts.
- **FR-010**: System MUST allow authenticated users to log out at any time, immediately terminating the active application session.
- **FR-011**: System MUST redirect unauthenticated requests attempting to access protected workspace views to the sign-in screen featuring the "Sign in with Google" option.
- **FR-012**: System MUST display user-friendly feedback when a federated authentication attempt is canceled, fails, or encounters an identity provider error.
- **FR-013**: System MUST enforce session idle timeout policies, requiring re-authentication via Google when a session has expired while safeguarding unsubmitted form text where possible.
- **FR-014**: System MUST decommission and remove the user invitation form and invitation creation endpoints, replacing the invite workflow with direct public URL access.
- **FR-015**: System MUST route first-time registered users directly to their personal workspace upon successful Google sign-in without interposing intermediate profile setup or terms screens, populating display name and email directly from their Google profile.
- **FR-016**: System MUST accept authentications from any valid, verified Google account without domain restrictions, permitting both consumer (@gmail.com) and custom Google Workspace domain accounts to register and log in.
- **FR-017**: System MUST use an AWS Cognito User Pool as the central user directory to store user profile information, including unique user subject identifier, verified email, display name, and federated identity provider linkage.
- **FR-018**: System MUST automatically provision and synchronize user records in the AWS Cognito User Pool upon successful first-time and returning Google sign-in.

### Key Entities

- **User Account**: Represents a registered individual on the platform, maintained in the AWS Cognito User Pool as the authoritative identity store.
  - *Attributes*: Unique user identifier (`sub`), verified email address, federated identity provider link (Google subject identifier), display name / profile attributes, registration method (`google_self_registered`, `invited`, `admin_provisioned`), account status (`active`, `suspended`), creation timestamp, last login timestamp.
- **User Session**: Represents an active, authenticated session for a user.
  - *Attributes*: Unique session identifier / tokens (issued by AWS Cognito), user identifier (`sub`), issued timestamp, expiration timestamp, active status.
- **Idea**: Represents an idea entry authored and owned by a user.
  - *Attributes*: Unique idea identifier, owner user identifier, content text, creation timestamp, last updated timestamp.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of new visitors can create a new account and access their personal workspace using the "Sign in with Google" button without an invitation.
- **SC-002**: New account provisioning and direct entry to the initialized personal workspace complete in under 3 seconds following Google authentication consent under normal network conditions.
- **SC-003**: Returning users can log in via the "Sign in with Google" button and reach their personal workspace within 2 seconds.
- **SC-004**: 100% of user data and submitted ideas are strictly isolated to the authoring user account, achieving zero unauthorized cross-user data exposure.
- **SC-005**: 0% data loss or account duplication occurs when users with pre-existing or invited accounts sign in via Google.
- **SC-006**: Canceled or dismissed Google sign-in attempts return the user cleanly to the entry screen with helpful feedback in under 1 second.
- **SC-007**: Zero internal password storage or password transmission required; authentication delegation to Google federated identity via AWS Cognito is 100% compliant with standard identity protocols.
- **SC-008**: 100% of unauthenticated access attempts to protected workspace views or idea operations are blocked and redirected to the sign-in prompt.

## Assumptions

- Federated Google SSO is integrated through an AWS Cognito User Pool as the central identity directory and authentication broker; internal username and password management is deliberately excluded to prevent credential storage risks.
- Public self-registration is globally unrestricted, permitting any valid, verified Google account (including consumer @gmail.com and custom Google Workspace domains) to register and log in.
- Users who were previously invited or provisioned retain full access to their accounts and existing data using their registered Google email.
- The legacy user invitation UI and invitation creation endpoints are decommissioned and removed; users join directly by navigating to the application and authenticating with Google.
- Session lifetime policies remain aligned with existing application security rules (1-hour idle expiration window).
- Application data ownership guarantees established in prior iterations are maintained, with each user having their own private idea repository.
- Administrative controls (such as the ability to suspend accounts or inspect security logs) are retained for platform governance.
