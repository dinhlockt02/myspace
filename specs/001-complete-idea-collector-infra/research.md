# Research & Decisions: Complete Idea Collector Infrastructure

## 1. Backend Ingestion Architecture

**Task**: Research the optimal serverless architecture for an ingestion API backed by a database table using Terraform in AWS.

**Decision**: Use AWS API Gateway HTTP API (v2) integrated with a single AWS Lambda function, backed by an AWS DynamoDB table.

**Rationale**: 
- HTTP APIs (v2) are cheaper, faster, and simpler than REST APIs (v1) and fully support proxy integrations to Lambda.
- A single Lambda function is sufficient to handle the `POST /ideas` ingestion and payload validation.
- DynamoDB offers a fully managed, serverless NoSQL database ideal for storing schema-less or simple records (like ideas and timestamps) with high availability and low latency.
- Fits seamlessly into Terraform using standard `aws_apigatewayv2_*`, `aws_lambda_*`, and `aws_dynamodb_table` resources.

**Alternatives considered**:
- API Gateway REST API (v1): Overkill for a simple ingestion endpoint.
- AWS S3 for storage: Not ideal for concurrent, individual record inserts; DynamoDB is better suited for unstructured/semi-structured record ingestion.

## 2. Unified Domain Routing (CloudFront Multiple Origins)

**Task**: Find best practices for routing `/api/*` traffic to API Gateway and other traffic to S3 within the same CloudFront distribution.

**Decision**: Configure the existing CloudFront distribution with two origins: the S3 bucket (default) and the API Gateway HTTP API (custom origin). Add a Cache Behavior for the path pattern `/api/*` pointing to the API Gateway origin.

**Rationale**:
- Meets the requirement of "Unified Domain Routing" (FR-010).
- Eliminates CORS preflight requests since both the frontend and API share the same origin (`idea.dinhloc.dev`).
- Cache behavior for `/api/*` must disable caching (`Managed-CachingDisabled` policy) and forward necessary headers (like `Authorization` if added later) and HTTP methods (POST, PUT, DELETE, etc.).

**Alternatives considered**:
- Dedicated API Subdomain (`api.idea.dinhloc.dev`): Rejected based on the clarification favoring unified domain routing to simplify CORS and SSL management.

## 3. Automated Frontend Deployment

**Task**: Research how to automate the build and deployment of the frontend static assets and edge cache invalidation using existing Nx targets and GitHub Actions.

**Decision**: Add an `deploy` executor target to `apps/idea-collector/frontend/project.json` that uses the AWS CLI to sync the `dist/` directory to the S3 bucket and create a CloudFront invalidation.

**Rationale**:
- Aligns with the project's use of Nx for task orchestration.
- The CI/CD workflow (`.github/workflows/on_push_main.yml`) can easily trigger `pnpm nx run idea-collector-frontend:deploy` after building.
- Ensures zero manual console configuration steps (SC-005) and automates asset synchronization (FR-011).

**Alternatives considered**:
- Terraform `aws_s3_object`: Not recommended for syncing entire build directories (like Vite's `dist`) due to state bloat and complexity. Native AWS CLI (`aws s3 sync`) is the industry standard for this task.
