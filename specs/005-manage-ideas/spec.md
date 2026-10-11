# Feature Specification: Idea Management and AI Categorization

**Feature Branch**: `005-manage-ideas`

**Created**: 2026-10-11

**Status**: Draft

**Input**: User description: "as an user of idea collector, I would like to manage my ideas. The flow is following. When I input new idea, it will passthrough an AI for classify. Then, it will store in dynamodb with it category. I can view and manage idea in a managing screen."

## Clarifications

### Session 2026-10-11

- Q: How should the AI classifier categorize ideas, and what category structure should be used? → A: User-Configurable Categories: The system provides default categories (Feature, Improvement, Bug, Business, Personal, Other) while allowing users to create, modify, and delete custom categories; the AI classifier classifies submissions against the active category set.
- Q: Should the AI classification run synchronously during submission, or asynchronously in the background? → A: Asynchronous Background Classification: The intake API writes the idea to DynamoDB immediately with a "Pending" classification status and responds quickly (<500ms); an asynchronous background process (e.g., DynamoDB Streams / async worker) invokes the AI classification service and updates the record with the determined category.
- Q: What management actions should users be permitted to perform on existing ideas in the management screen? → A: Full Management: Users have full CRUD control on the management screen—viewing ideas, editing idea text, manually reassigning categories, and permanently deleting ideas (with a confirmation step).
- Q: Should the ideas and management screen be isolated per user, or shared across all users? → A: User-Isolated: Each user strictly views, edits, and manages their own ideas; DynamoDB data partitioning and API access controls enforce per-user data isolation using authenticated user IDs.
- Q: Which AI service or provider should the background classifier integrate with to categorize ideas? → A: Pluggable Provider Interface (Initial: AWS Bedrock): The classification layer is designed with an extensible interface supporting pluggable AI providers, with AWS Bedrock (e.g., Claude 3 Haiku / Amazon Titan) implemented as the initial provider using native IAM role permissions.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Instant Idea Submission with Asynchronous AI Classification (Priority: P1)

An authenticated idea collector user enters a new idea into the submission interface and submits it. The system immediately stores the idea in DynamoDB associated with the user's account (`user_id`) with a status of `pending` classification, returning an instant confirmation to the user within 500ms. In the background, an automated worker processes the newly created idea, invokes the AI classification service (via AWS Bedrock) to evaluate the text against the user's active category set (system defaults and user custom categories), and updates the DynamoDB record with the assigned category and sets the classification status to `completed`.

**Why this priority**: Core value proposition. Provides a frictionless, low-latency intake experience while ensuring ideas are automatically enriched with AI-generated categories in the background and isolated to the author.

**Independent Test**: Can be tested independently by submitting an idea text via the intake form as an authenticated user, verifying immediate HTTP response with `pending` status, and confirming that within several seconds the DynamoDB record is updated with the resolved category, `user_id`, and `completed` status.

**Acceptance Scenarios**:

1. **Given** an authenticated user inputs a valid idea text, **When** they submit, **Then** the system immediately persists the idea with the user's `user_id` and `classification_status: "pending"`, returning an acknowledgment in <500ms.
2. **Given** a pending idea record in DynamoDB, **When** the asynchronous background classifier executes, **Then** it assigns a matching category from the user's active category set and updates the record to `classification_status: "completed"`.
3. **Given** the classification service is unavailable or encounters a permanent error, **When** the background process exhausts its retries, **Then** the idea is updated to a fallback category ("Other") with `classification_status: "failed"` or `"completed"`, preventing stranded pending records.

---

### User Story 2 - Idea Management Screen: Viewing and Browsing Ideas (Priority: P2)

An authenticated idea collector user navigates to the Idea Management screen to view their personal collection of ideas. The management screen displays only ideas belonging to the authenticated user in reverse chronological order, displaying each idea's content, assigned category (or a visual "Classifying..." badge if pending), creation timestamp, and status. Users can filter ideas by category or status.

**Why this priority**: Users need private visibility into their own collection of ideas, real-time status of pending classifications, and the ability to organize their personal knowledge base.

**Independent Test**: Can be tested independently by loading the management screen with pre-populated categorized and pending ideas for the signed-in user, verifying that other users' ideas are never shown, verifying visual rendering of categories and pending indicators, and verifying working category filters.

**Acceptance Scenarios**:

1. **Given** stored ideas exist for the authenticated user, **When** the user accesses the management screen, **Then** only their own ideas are listed with content, category/pending status, and creation date in reverse chronological order.
2. **Given** ideas currently undergoing background classification, **When** displayed on the management screen, **Then** they show a distinct "Classifying..." badge until resolved.
3. **Given** a list of ideas across multiple categories, **When** the user filters by a specific category, **Then** only ideas matching that category are displayed.
4. **Given** no ideas have been submitted yet by the user, **When** they open the management screen, **Then** a friendly empty state is displayed with a prompt to submit a new idea.

---

### User Story 3 - Managing and Updating Idea Details and Categories (Priority: P3)

An authenticated user reviews their ideas on the management screen and performs full management actions: updating its category, editing its description, or deleting obsolete ideas. When deleting an idea, the user is presented with a clear confirmation dialog to prevent accidental deletion. Additionally, users can create and manage their own custom categories directly on the management screen.

**Why this priority**: Automated classification can occasionally produce imprecise results, and idea lifecycles require curation, updates, and personalized taxonomy customization.

**Independent Test**: Can be tested independently by selecting an existing idea on the management screen, changing its category or text, confirming deletion removes the idea upon confirmation, verifying unauthorized modifications to others' ideas are blocked, and confirming changes persist in DynamoDB.

**Acceptance Scenarios**:

1. **Given** an existing idea owned by the user, **When** the user reassigns or corrects the category, **Then** the updated category is saved and reflected in the UI.
2. **Given** an existing idea owned by the user, **When** the user edits the idea text, **Then** the updated text is saved with a modification timestamp.
3. **Given** an unwanted idea owned by the user, **When** the user clicks delete, **Then** a confirmation prompt is displayed; upon confirmation, the idea is permanently removed from DynamoDB.
4. **Given** a user wishing to track a new domain, **When** they add a custom category on the management screen, **Then** that category is saved for their account and becomes immediately available for filtering, manual assignment, and future AI classifications.
5. **Given** a user attempting to edit or delete an idea belonging to another user, **When** the request is received, **Then** the system rejects the operation with an authorization error.

---

### Edge Cases

- **AI Classification Service Downtime / Rate Limiting**: What happens if the AI classification API is unavailable, throttled, or returns an error during background processing? Background worker retries up to 3 times before setting category to "Other" with failed status.
- **Empty / Ambiguous Idea Text**: How does the classifier handle extremely short or ambiguous idea inputs (e.g., "test", single words, or gibberish)? Classifier assigns "Other" or "General".
- **Custom Category Deletion**: What happens to ideas assigned to a custom category if that category is deleted or renamed by the user? Ideas retain the category label or are reassigned to "Other".
- **Management Screen State Sync**: How does the user see newly classified ideas if classification completes while the user is viewing the page? The page offers a refresh button or re-fetches when pending items exist.
- **Cross-User Data Leakage**: How does the system prevent unauthorized access across accounts? DynamoDB partition queries and API layer strictly scope all reads/writes by the validated session `user_id`.
- **Accidental Deletion**: How does the system prevent accidental loss? Deletion requires explicit user confirmation.
- **Concurrent Updates**: How does the system handle simultaneous edits or deletions of the same idea? Last-write-wins with optimistic UI feedback.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow authenticated users to submit new ideas containing descriptive text.
- **FR-002**: System MUST immediately persist submitted ideas to DynamoDB with the user's `user_id`, `classification_status: "pending"`, and return an intake response within 500ms.
- **FR-003**: System MUST execute asynchronous background AI classification on newly created ideas via a pluggable provider interface (with AWS Bedrock as the initial implementation via IAM role permissions), evaluating idea content against the author's active category set.
- **FR-004**: System MUST update the idea record in DynamoDB with the resolved category and set `classification_status: "completed"` upon successful classification.
- **FR-005**: System MUST assign a fallback category (e.g., "Other") and update `classification_status` if background classification fails after retries, ensuring no ideas remain stranded.
- **FR-006**: System MUST provide a management screen displaying collected ideas strictly scoped to the authenticated user, showing associated categories, classification status (completed vs pending), timestamps, and identifiers.
- **FR-007**: System MUST support filtering ideas by category and classification status on the management screen.
- **FR-008**: Users MUST be able to manually edit an idea's text and reassign its category on the management screen for ideas they own.
- **FR-009**: Users MUST be able to delete ideas they own from the management screen with an explicit confirmation step before permanent removal.
- **FR-010**: System MUST enforce user data isolation, prohibiting users from viewing, editing, or deleting ideas belonging to other users.
- **FR-011**: System MUST support pagination or limiting for idea listings to ensure high performance with large datasets.
- **FR-012**: System MUST allow users to view, create, edit, and delete custom categories scoped to their account, which are incorporated into future AI classification prompts for that user.

### Key Entities *(include if feature involves data)*

- **Idea**: Represents an individual submitted concept. Contains attributes: `id` (unique identifier), `user_id` (owner identifier, partition key), `text` (idea description), `category` (assigned category name/tag), `classification_status` (`pending` | `completed` | `failed`), `created_at` (timestamp), and `updated_at` (timestamp).
- **Category**: Represents a classification label. Contains attributes: `id` (identifier), `user_id` (owner identifier for custom categories; null/system for defaults), `name` (label, e.g., "Feature", "Enhancement", "Bug", "Productivity"), `is_system_defined` (boolean), and `created_at` (timestamp).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ideas submitted through the intake interface are acknowledged and persisted in DynamoDB in under 500ms under normal conditions.
- **SC-002**: Asynchronous background AI classification completes and updates the DynamoDB record within 10 seconds of submission.
- **SC-003**: 100% of submitted ideas reach a final classification status (`completed` or fallback `failed`), with zero stranded pending ideas.
- **SC-004**: The idea management screen loads and displays the authenticated user's ideas within 1.5 seconds.
- **SC-005**: 100% of queries and mutations on ideas enforce user isolation; zero unauthorized access to other users' ideas.
- **SC-006**: Users can filter, edit, or delete any idea on the management screen with immediate visual confirmation within 1 second.
- **SC-007**: Category correction workflow allows a user to override an AI-assigned category in 2 clicks or fewer.
- **SC-008**: Users can add a new custom category in under 30 seconds, immediately reflecting in classification options.

## Assumptions

- **Target Audience & Auth**: Authenticated users accessing the web application; user session provides a validated user ID for scoping requests.
- **Classification Taxonomy**: Hybrid model with system default categories (Feature, Improvement, Bug, Business, Personal, Other) and user-defined custom categories.
- **Storage Backend**: DynamoDB is used for persistence, partitioned by `user_id` to enforce data isolation.
- **AI Provider & Architecture**: Pluggable provider architecture with AWS Bedrock as the initial default provider, communicating via AWS SDK with IAM role authorization.
- **AI Processing Model**: Asynchronous background processing triggered via DynamoDB Streams, event queues, or background worker.
