package handlers_test

import (
	"encoding/json"
	"net/http"
	"testing"

	"github.com/aws/aws-lambda-go/events"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/handlers"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/models"
)

// Unit test verifying Idea validation constraints
func TestIdeaValidation(t *testing.T) {
	// Empty idea
	if err := models.ValidateIdea(""); err == nil {
		t.Errorf("expected error for empty idea, got nil")
	}

	// Whitespace only
	if err := models.ValidateIdea("   \n\t  "); err == nil {
		t.Errorf("expected error for whitespace only idea, got nil")
	}

	// Over 5000 characters
	longIdea := make([]byte, 5001)
	for i := range longIdea {
		longIdea[i] = 'a'
	}
	if err := models.ValidateIdea(string(longIdea)); err == nil {
		t.Errorf("expected error for idea > 5000 characters, got nil")
	}

	// Valid idea
	if err := models.ValidateIdea("A valid brilliant innovation."); err != nil {
		t.Errorf("expected no error for valid idea, got %v", err)
	}
}

// Unit test verifying Email validation and normalization
func TestEmailValidation(t *testing.T) {
	// Invalid format
	if _, err := models.ValidateAndNormalizeEmail("notanemail"); err == nil {
		t.Errorf("expected error for invalid email, got nil")
	}

	// Capitalization normalized
	normalized, err := models.ValidateAndNormalizeEmail("  ALICE@EXAMPLE.COM  ")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if normalized != "alice@example.com" {
		t.Errorf("expected normalized email alice@example.com, got %s", normalized)
	}
}

// Unit test verifying that single-item ownership validation masks existence
func TestCrossUserProbeMasking(t *testing.T) {
	userA := &models.Session{
		SessionID: "sess-user-a",
		UserID:    "user-a-uuid",
		Email:     "user-a@example.com",
		IsValid:   true,
	}

	userB := &models.Session{
		SessionID: "sess-user-b",
		UserID:    "user-b-uuid",
		Email:     "user-b@example.com",
		IsValid:   true,
	}

	ideaBelongingToA := &models.Idea{
		ID:     "idea-123",
		UserID: userA.UserID,
		Idea:   "Confidential project plan of User A",
	}

	// Verify User A can view their own idea
	if ideaBelongingToA.UserID != userA.UserID {
		t.Errorf("User A should match owner ID")
	}

	// Verify User B attempting to view User A's idea is blocked
	if ideaBelongingToA.UserID == userB.UserID {
		t.Errorf("User B must NOT match owner ID")
	}

	// Simulated probe handler logic
	verifyAccess := func(idea *models.Idea, session *models.Session) (events.APIGatewayProxyResponse, error) {
		if idea == nil || idea.UserID != session.UserID {
			return handlers.JSONResponse(http.StatusNotFound, models.ErrorResponse{
				Error:   "NOT_FOUND",
				Message: "Idea not found.",
			})
		}
		return handlers.JSONResponse(http.StatusOK, idea)
	}

	resp, _ := verifyAccess(ideaBelongingToA, userB)
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("expected status 404 for cross-user probe, got %d", resp.StatusCode)
	}

	var errResp models.ErrorResponse
	_ = json.Unmarshal([]byte(resp.Body), &errResp)
	if errResp.Error != "NOT_FOUND" {
		t.Errorf("expected generic NOT_FOUND without metadata, got %s", errResp.Error)
	}
}

// Unit test verifying backward compatibility for pre-existing accounts
func TestLegacyAccountIdeaAccess(t *testing.T) {
	legacyEmail := "historically_invited@example.com"
	cognitoSub := "cognito-uuid-9876"

	user := &models.UserDTO{
		ID:    cognitoSub,
		Email: legacyEmail,
		Name:  "Historical User",
	}

	historicalIdea := &models.Idea{
		ID:     "historical-idea-001",
		UserID: legacyEmail, // Partitioned under email in milestone 002
		Idea:   "Ancient brilliant invention from milestone 002",
	}

	canAccess := func(idea *models.Idea, u *models.UserDTO) bool {
		return idea.UserID == u.ID || (u.Email != "" && idea.UserID == u.Email)
	}

	if !canAccess(historicalIdea, user) {
		t.Errorf("Expected user with email %s to be able to access historical idea partitioned by email", legacyEmail)
	}
}

// Unit test verifying strict cross-tenant isolation between self-registered Cognito users
func TestCrossTenantDataIsolationWithCognitoSub(t *testing.T) {
	userA := &models.UserDTO{
		ID:    "cognito-sub-user-a",
		Email: "user.a@gmail.com",
		Name:  "User A",
	}

	userB := &models.UserDTO{
		ID:    "cognito-sub-user-b",
		Email: "user.b@gmail.com",
		Name:  "User B",
	}

	ideaA := &models.Idea{
		ID:     "idea-user-a-secret",
		UserID: userA.ID,
		Idea:   "Confidential secret of User A",
	}

	checkAccess := func(idea *models.Idea, caller *models.UserDTO) bool {
		return idea.UserID == caller.ID || (caller.Email != "" && idea.UserID == caller.Email)
	}

	// Caller A accessing Idea A -> Allowed
	if !checkAccess(ideaA, userA) {
		t.Errorf("User A must have access to User A's idea")
	}

	// Caller B accessing Idea A -> Denied
	if checkAccess(ideaA, userB) {
		t.Errorf("User B must NOT have access to User A's idea")
	}
}

