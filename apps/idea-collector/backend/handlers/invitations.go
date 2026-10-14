package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/google/uuid"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/models"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/repository"
)

type InvitationsHandler struct {
	repo *repository.Repository
}

func NewInvitationsHandler(repo *repository.Repository) *InvitationsHandler {
	return &InvitationsHandler{repo: repo}
}

// HandleCreateInvitation handles POST /api/invitations
func (h *InvitationsHandler) HandleCreateInvitation(ctx context.Context, req events.APIGatewayProxyRequest, session *models.Session) (events.APIGatewayProxyResponse, error) {
	var payload models.InvitationRequest
	if err := json.Unmarshal([]byte(req.Body), &payload); err != nil {
		return JSONResponse(http.StatusBadRequest, models.ErrorResponse{
			Error:   "INVALID_JSON",
			Message: "Could not parse invitation payload.",
		})
	}

	normalizedEmail, err := models.ValidateAndNormalizeEmail(payload.Email)
	if err != nil {
		return JSONResponse(http.StatusBadRequest, models.ErrorResponse{
			Error:   "INVALID_EMAIL",
			Message: err.Error(),
		})
	}

	// Prevent self-invitation
	if normalizedEmail == session.Email {
		return JSONResponse(http.StatusBadRequest, models.ErrorResponse{
			Error:   "SELF_INVITATION",
			Message: "Cannot invite your own currently authenticated email address.",
		})
	}

	// Check if already provisioned / invited / active
	existingUser, err := h.repo.GetUserByEmail(ctx, normalizedEmail)
	if err == nil && existingUser != nil {
		return JSONResponse(http.StatusConflict, models.ErrorResponse{
			Error:   "USER_ALREADY_EXISTS",
			Message: "The specified email address has already been invited or is active.",
		})
	} else if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return JSONResponse(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "INTERNAL_ERROR",
			Message: "Failed to verify invitation status.",
		})
	}

	nowMs := float64(time.Now().UnixNano()) / 1e6
	newUser := &models.User{
		Email:           normalizedEmail,
		ID:              uuid.New().String(),
		Status:          "invited",
		InvitedByUserID: session.UserID,
		CreatedAt:       nowMs,
	}

	if err := h.repo.CreateUser(ctx, newUser); err != nil {
		return JSONResponse(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "INTERNAL_ERROR",
			Message: "Failed to create invitation record.",
		})
	}

	return JSONResponse(http.StatusCreated, models.InvitationResponse{
		Success: true,
		Message: "Invitation created successfully.",
		Email:   normalizedEmail,
	})
}
