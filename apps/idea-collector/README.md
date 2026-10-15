# Idea Collector

A modern, serverless web application to capture and organize ideas in private, isolated workspaces.

## Architecture

- **Frontend**: React 19 + TypeScript + Vite SPA hosted on AWS S3 & CloudFront (`idea.dinhloc.dev`)
- **Authentication & Directory**: AWS Cognito User Pool with Google as a federated Social Identity Provider (OIDC). Open public self-registration via PKCE without invitation gates.
- **Backend API**: AWS Lambda running Go 1.26 on `provided.al2023`
- **Edge Security**: AWS API Gateway HTTP API v2 with native Cognito JWT Authorizer
- **Storage**: AWS DynamoDB (`IdeaCollector_Ideas` table with `UserIdeasIndex` GSI)
- **Infrastructure as Code**: Terraform with remote state management

## Structure

```text
apps/idea-collector/
├── frontend/    # React 19 SPA with Cognito OAuth2 PKCE authentication
├── backend/     # Go serverless Lambda handlers and DynamoDB repository
└── infra/       # Terraform AWS infrastructure (Cognito, API Gateway, S3, CloudFront)
```

## Authentication & Onboarding

1. Users click **Sign in with Google** on the landing page.
2. The browser is directed to AWS Cognito's `/oauth2/authorize` endpoint with `identity_provider=Google` and PKCE (`S256`).
3. Google authenticates the user and returns an authorization code.
4. Cognito automatically provisions the user in the User Pool (Just-In-Time) and issues JWT tokens (ID Token & Access Token).
5. The user lands directly in their personal workspace. No invitation code or intermediate forms required.

## Development

```bash
# Frontend
cd apps/idea-collector/frontend
pnpm install
pnpm dev

# Backend
cd apps/idea-collector/backend
go test -v ./...
go build -o bootstrap main.go
```
