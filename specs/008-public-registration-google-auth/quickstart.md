# Quickstart & Verification Guide: Public Registration with AWS Cognito & Google Auth

This guide provides step-by-step instructions and runnable test scenarios to validate the implementation of open public registration, AWS Cognito integration, and federated Google authentication.

---

## 1. Prerequisites & Environment Setup

### Required Tooling
- **Go**: 1.22+ (Backend Lambda)
- **Node.js**: 20+ and **pnpm**: 9+ (Frontend SPA)
- **Terraform**: 1.9+ with AWS Provider ~> 5.0
- **AWS CLI**: Authenticated with appropriate dev permissions

### Environment Variables

#### Backend (`apps/idea-collector/backend/.env`)
```bash
TABLE_NAME="IdeaCollector_Ideas"
COGNITO_USER_POOL_ID="us-east-1_xxxxxxxxx"
COGNITO_APP_CLIENT_ID="xxxxxxxxxxxxxxxxxxxxxxxxxx"
AWS_REGION="us-east-1"
```

#### Frontend (`apps/idea-collector/frontend/.env`)
```bash
VITE_API_BASE_URL="http://localhost:8080" # or API Gateway endpoint
VITE_COGNITO_DOMAIN="https://auth.idea.dinhloc.dev" # or https://<domain-prefix>.auth.<region>.amazoncognito.com
VITE_COGNITO_CLIENT_ID="xxxxxxxxxxxxxxxxxxxxxxxxxx"
VITE_COGNITO_REDIRECT_URI="http://localhost:5173"
```

---

## 2. Local Execution Commands

### Run Backend Unit & Contract Tests
```bash
cd apps/idea-collector/backend
go test -v -race ./...
```

### Validate Infrastructure Configurations
```bash
cd apps/idea-collector/infra
terraform init -backend=false
terraform validate
```

### Start Frontend Application
```bash
cd apps/idea-collector/frontend
pnpm install
pnpm dev
```

---

## 3. End-to-End Verification Scenarios

### Scenario 1: Public Self-Registration via "Sign in with Google" (P1)
**Goal**: Verify an uninvited user can register and access their workspace with zero invitation prerequisites.

1. Open an incognito browser window and navigate to `http://localhost:5173`.
2. **Observe**: The entry screen displays a prominent "Sign in with Google" button. There are no invitation code inputs or waitlist messages.
3. Click "Sign in with Google".
4. **Result**: Browser redirects to Google consent prompt (or simulated OAuth test identity). Complete sign-in with a fresh test Google account (`newuser@example.com`).
5. **Verify**:
   - Browser redirects back to the application.
   - Cognito automatically provisions the user in the User Pool.
   - User lands immediately on their personal workspace.
   - Welcome message / empty state is displayed: *"No ideas yet. Submit your first idea!"*.

---

### Scenario 2: Direct Workspace Entry (No Intermediate Modals) (P1)
**Goal**: Confirm that first-time registration does not display profile setup or terms acknowledgement screens.

1. Using the fresh account from Scenario 1, verify that navigation transitions directly from the OAuth callback to the idea collection workspace.
2. Check that the header displays the user's name and email as retrieved from the Cognito ID token.
3. Confirm that no intermediate onboarding modal appeared between authentication and workspace render.

---

### Scenario 3: Returning User Sign-In & Session Persistence (P1)
**Goal**: Verify a returning user logs in seamlessly and retrieves their existing ideas.

1. In the workspace, submit an idea: *"Validate Cognito federated auth"*.
2. Click **Log Out** in the header.
3. **Verify**: Session terminates, tokens are cleared, and user returns to public sign-in page.
4. Click "Sign in with Google" and authenticate with the same account.
5. **Verify**: User returns directly to their workspace with the idea *"Validate Cognito federated auth"* visible.

---

### Scenario 4: Cross-User Data Isolation (P2)
**Goal**: Ensure User A cannot view, query, or infer User B's ideas.

1. While logged in as User A (`usera@example.com`), author idea: *"Secret strategy for User A"*. Note the idea ID.
2. Log out, then log in as User B (`userb@example.com`).
3. **Verify in UI**: User B's workspace displays only User B's ideas (or empty state), and does not show *"Secret strategy for User A"*.
4. **API Direct Test**: Using User B's Cognito access token, attempt a GET request referencing User A's idea ID or query parameters.
5. **Verify**: Request returns empty or 403 Forbidden; zero cross-tenant data leakage.

---

### Scenario 5: Decommissioned Invitation Subsystem Verification (P2)
**Goal**: Prove that invitation forms and endpoints are completely removed.

1. Inspect the workspace UI: Verify that the "Invite" button / modal is entirely absent.
2. Send a `POST /api/invitations` request with a valid Cognito Bearer token:
   ```bash
   curl -i -X POST "$API_BASE_URL/api/invitations" \
     -H "Authorization: Bearer $COGNITO_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"email": "friend@example.com"}'
   ```
3. **Verify**: API Gateway returns `404 Not Found` (route removed) or backend confirms decommissioning.

---

### Scenario 6: Session Expiration & Draft Preservation (P3)
**Goal**: Ensure expired sessions prompt re-authentication without losing in-flight draft text.

1. Type text into the idea submission box: *"Valuable thought before expiration"*. Do not click Submit.
2. Manually invalidate or expire the local session token in local storage / session state.
3. Attempt to submit the idea.
4. **Verify**: Application detects the expired token, halts submission, prompts for Google re-authentication, and preserves the text *"Valuable thought before expiration"* in the input field.
