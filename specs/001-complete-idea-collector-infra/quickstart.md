# Quickstart: Validation Guide for Idea Collector Infrastructure

This guide outlines how to validate the complete idea collector infrastructure end-to-end once it has been deployed.

## Prerequisites

- The infrastructure has been provisioned via Terraform (`apps/idea-collector/infra`).
- The frontend has been built and deployed to S3 via Nx/GitHub Actions.
- The `idea.dinhloc.dev` domain DNS records have propagated and point to the CloudFront distribution.

## Scenario 1: Validate Frontend Delivery and Redirection

1. **Test HTTP to HTTPS redirection:**
   ```bash
   curl -I http://idea.dinhloc.dev
   ```
   *Expected Output*: You should receive a `301 Moved Permanently` response pointing to `https://idea.dinhloc.dev`.

2. **Test Secure Frontend Delivery:**
   ```bash
   curl -I https://idea.dinhloc.dev
   ```
   *Expected Output*: You should receive a `200 OK` response with headers indicating it was served by CloudFront (e.g., `x-cache: Hit from cloudfront`).

3. **Test SPA Routing (Fallback to index.html):**
   ```bash
   curl -I https://idea.dinhloc.dev/some-random-client-path
   ```
   *Expected Output*: You should receive a `200 OK` response returning the `index.html` file, demonstrating that CloudFront is correctly redirecting non-API unmatched paths to the single-page application entry point.

## Scenario 2: Validate Unified Domain API Routing and Ingestion

1. **Test API Routing and Success:**
   Send a valid idea submission payload to the unified domain API path.
   ```bash
   curl -X POST https://idea.dinhloc.dev/api/ideas \
     -H "Content-Type: application/json" \
     -d '{"idea": "Deploy a complete infrastructure test.", "timestamp": 1696200000000}'
   ```
   *Expected Output*:
   - HTTP Status: `201 Created`
   - Response Body: `{"success": true, "id": "<uuid>", "message": "Idea successfully submitted."}`
   - The lack of CORS issues or API-not-found errors validates the CloudFront cache behavior for `/api/*`.

2. **Test API Validation (Error Case):**
   Send an empty idea to ensure the backend validates the payload.
   ```bash
   curl -X POST https://idea.dinhloc.dev/api/ideas \
     -H "Content-Type: application/json" \
     -d '{"idea": "", "timestamp": 1696200000000}'
   ```
   *Expected Output*:
   - HTTP Status: `400 Bad Request`
   - Response Body containing validation error details.

3. **Verify Data Persistence (Optional via AWS CLI):**
   Check the DynamoDB table to ensure the idea was stored durably.
   ```bash
   aws dynamodb scan --table-name IdeaCollector_Ideas
   ```
   *Expected Output*: The items list should include the record submitted in Step 1.
