# Tasks: Complete Idea Collector Infrastructure

**Input**: Design documents from `/specs/001-complete-idea-collector-infra/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Testing is implemented natively via infrastructure deployment success and quickstart validation. No dedicated unit test tasks were requested.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Initialize Go backend module in `apps/idea-collector/backend/go.mod`
- [x] T002 Add `github.com/aws/aws-lambda-go` and AWS SDK v2 dependencies to `apps/idea-collector/backend/go.mod`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Define shared Terraform variables (e.g., domain name `idea.dinhloc.dev`) in `apps/idea-collector/infra/variables.tf`
- [x] T004 Provision DynamoDB Table `IdeaCollector_Ideas` (Partition Key: `id` String) in `apps/idea-collector/infra/main.tf`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Secure and Reliable Portal Access (Priority: P1) 🎯 MVP

**Goal**: Deliver the React frontend securely over HTTPS via CloudFront/S3 under `idea.dinhloc.dev` with HTTP to HTTPS redirection.

**Independent Test**: Navigate to `http://idea.dinhloc.dev` and verify a successful redirect and load from HTTPS.

### Implementation for User Story 1

- [x] T005 [P] [US1] Provision S3 bucket for static hosting (blocking direct public access) in `apps/idea-collector/infra/main.tf`
- [x] T006 [P] [US1] Provision ACM Certificate for `idea.dinhloc.dev` and Route53 validation records in `apps/idea-collector/infra/main.tf`
- [x] T007 [US1] Provision CloudFront distribution for the S3 bucket with HTTPS redirection, OAC, and SPA fallback (`index.html`) in `apps/idea-collector/infra/main.tf` (depends on T005, T006)
- [x] T008 [US1] Create Route53 alias record pointing `idea.dinhloc.dev` to the CloudFront distribution in `apps/idea-collector/infra/main.tf` (depends on T007)

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Idea Ingestion and Durable Persistence (Priority: P1)

**Goal**: Implement backend ingestion API (API Gateway + Lambda) to validate and store ideas in DynamoDB.

**Independent Test**: Send a valid POST request to the API Gateway endpoint URL directly to verify successful insertion into DynamoDB.

### Implementation for User Story 2

- [x] T009 [P] [US2] Create Go data model `IdeaSubmissionRequest` and validation logic (`idea` must be 1 to 5000 characters, `timestamp` must be provided) in `apps/idea-collector/backend/main.go`
- [x] T010 [P] [US2] Create Makefile to build Go Lambda binary for AWS Linux environment in `apps/idea-collector/backend/Makefile`
- [x] T011 [US2] Implement DynamoDB PutItem logic mapping data-model entities (`id` as UUIDv4, `client_timestamp`, `server_timestamp`) in `apps/idea-collector/backend/main.go`
- [x] T012 [US2] Implement API Gateway Lambda handler to process `POST` requests and return `201 Created` or `400 Bad Request` in `apps/idea-collector/backend/main.go`
- [x] T013 [P] [US2] Provision IAM execution role with DynamoDB write permissions and Lambda function resource in `apps/idea-collector/infra/main.tf`
- [x] T014 [US2] Provision HTTP API Gateway (v2) integrated with the Lambda function for `POST /api/ideas` in `apps/idea-collector/infra/main.tf`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Unified Path Routing (Priority: P2)

**Goal**: Route `/api/*` through CloudFront to the HTTP API Gateway origin, eliminating CORS issues.

**Independent Test**: Send a POST request to `https://idea.dinhloc.dev/api/ideas` and verify successful processing without CORS errors.

### Implementation for User Story 3

- [x] T015 [US3] Add the HTTP API Gateway as a custom origin to the CloudFront distribution in `apps/idea-collector/infra/main.tf`
- [x] T016 [US3] Add a new Cache Behavior for path pattern `/api/*` to the CloudFront distribution, disabling caching and forwarding all HTTP methods/headers in `apps/idea-collector/infra/main.tf`

**Checkpoint**: All user stories should now be independently functional under the unified domain

---

## Phase 6: User Story 4 - Automated Infrastructure Delivery and Asset Synchronization (Priority: P2)

**Goal**: Automate deployments with GitHub Actions and Nx.

**Independent Test**: Merge a PR and verify that Terraform applies successfully, frontend assets are synced to S3, and CloudFront cache is invalidated.

### Implementation for User Story 4

- [x] T017 [P] [US4] Add `deploy` target to `apps/idea-collector/frontend/project.json` using AWS CLI to sync the `dist/` directory to S3 and create a CloudFront invalidation
- [x] T018 [US4] Add CI/CD deployment jobs (Terraform apply and Nx deploy) for the `idea-collector` application in `.github/workflows/deploy.yml`

**Checkpoint**: Fully automated deployment pipeline is active.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T019 Execute the end-to-end validation guide steps documented in `specs/001-complete-idea-collector-infra/quickstart.md`
- [x] T020 Output deployment URLs and infrastructure statuses to Terraform outputs in `apps/idea-collector/infra/outputs.tf`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed sequentially or in parallel depending on capacity.
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 3 (P2)**: Depends on both US1 (CloudFront) and US2 (API Gateway)
- **User Story 4 (P2)**: Depends on US1 (S3 bucket and CloudFront) to exist for the Nx deploy target configuration.

### Parallel Opportunities

- T005, T006, and T009, T010, T013 can run in parallel since they touch independent files and AWS resources.
- US1 and US2 can be implemented completely independently by different agents/developers.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy (Frontend MVP)
3. Add User Story 2 → Test independently → Deploy (Backend MVP)
4. Add User Story 3 → Link Frontend & Backend on CloudFront
5. Add User Story 4 → Automate deployments

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Verify implementations against `quickstart.md`
