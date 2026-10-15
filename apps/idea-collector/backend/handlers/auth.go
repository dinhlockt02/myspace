package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/auth"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/models"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/repository"
)

type AuthHandler struct {
	repo           *repository.Repository
	verifier       *auth.GoogleTokenVerifier
	sessionManager *auth.SessionManager
}

func NewAuthHandler(repo *repository.Repository, verifier *auth.GoogleTokenVerifier, sessionManager *auth.SessionManager) *AuthHandler {
	return &AuthHandler{
		repo:           repo,
		verifier:       verifier,
		sessionManager: sessionManager,
	}
}

// HandleGoogleAuth handles POST /api/auth/google
func (h *AuthHandler) HandleGoogleAuth(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var payload models.GoogleAuthRequest
	if err := json.Unmarshal([]byte(req.Body), &payload); err != nil || payload.IDToken == "" {
		return JSONResponse(http.StatusBadRequest, models.ErrorResponse{
			Error:   "INVALID_REQUEST",
			Message: "Malformed request payload: id_token is required.",
		})
	}

	// Verify Google ID Token with Google JWKS
	tokenClaims, err := h.verifier.VerifyIDToken(payload.IDToken)
	if err != nil {
		return JSONResponse(http.StatusUnauthorized, models.ErrorResponse{
			Error:   "INVALID_TOKEN",
			Message: "Could not verify Google ID Token: " + err.Error(),
		})
	}

	// Verify invitation in IdeaCollector_Users
	user, err := h.repo.GetUserByEmail(ctx, tokenClaims.Email)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return JSONResponse(http.StatusForbidden, models.ErrorResponse{
				Error:   "ACCOUNT_NOT_INVITED",
				Message: "Account not authorized. An administrative or peer invitation is required.",
			})
		}
		return JSONResponse(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "INTERNAL_ERROR",
			Message: "Failed to verify account authorization.",
		})
	}

	if user.Status == "suspended" {
		return JSONResponse(http.StatusForbidden, models.ErrorResponse{
			Error:   "ACCOUNT_SUSPENDED",
			Message: "This account has been disabled or suspended.",
		})
	}

	nowMs := float64(time.Now().UnixNano()) / 1e6
	// Update user status to active and record google_sub on first or subsequent login
	_ = h.repo.UpdateUserOnLogin(ctx, user.Email, tokenClaims.Sub, nowMs)

	// Create 1-hour idle session
	session, err := h.sessionManager.CreateSession(ctx, user.ID, user.Email)
	if err != nil {
		return JSONResponse(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "INTERNAL_ERROR",
			Message: "Failed to establish user session.",
		})
	}

	resp := models.AuthSessionResponse{
		SessionToken: session.SessionID,
		ExpiresIn:    3600,
		User: models.UserDTO{
			ID:    user.ID,
			Email: user.Email,
		},
	}
	return JSONResponse(http.StatusOK, resp)
}

// HandleGetMe handles GET /api/auth/me
func (h *AuthHandler) HandleGetMe(ctx context.Context, user *models.UserDTO) (events.APIGatewayProxyResponse, error) {
	resp := models.UserProfileResponse{
		User:          *user,
		IdleExpiresIn: 3600,
	}
	return JSONResponse(http.StatusOK, resp)
}

// HandleLogout handles POST /api/auth/logout
func (h *AuthHandler) HandleLogout(ctx context.Context, user *models.UserDTO) (events.APIGatewayProxyResponse, error) {
	return JSONResponse(http.StatusOK, models.LogoutResponse{
		Success: true,
		Message: "Logged out successfully.",
	})
}

func JSONResponse(statusCode int, body interface{}) (events.APIGatewayProxyResponse, error) {
	b, _ := json.Marshal(body)
	return events.APIGatewayProxyResponse{
		StatusCode: statusCode,
		Headers: map[string]string{
			"Content-Type":                     "application/json",
			"Access-Control-Allow-Origin":      "*",
			"Access-Control-Allow-Headers":     "Content-Type,Authorization",
			"Access-Control-Allow-Methods":     "OPTIONS,POST,GET",
			"Access-Control-Allow-Credentials": "true",
		},
		Body: string(b),
	}, nil
}
