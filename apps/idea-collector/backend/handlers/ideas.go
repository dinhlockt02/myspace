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

type IdeasHandler struct {
	repo *repository.Repository
}

func NewIdeasHandler(repo *repository.Repository) *IdeasHandler {
	return &IdeasHandler{repo: repo}
}

// HandleSubmitIdea handles POST /api/ideas
func (h *IdeasHandler) HandleSubmitIdea(ctx context.Context, req events.APIGatewayProxyRequest, user *models.UserDTO) (events.APIGatewayProxyResponse, error) {
	var payload models.IdeaSubmissionRequest
	if err := json.Unmarshal([]byte(req.Body), &payload); err != nil {
		return JSONResponse(http.StatusBadRequest, models.ErrorResponse{
			Error:   "INVALID_JSON",
			Message: "Could not parse request body.",
		})
	}

	if err := models.ValidateIdea(payload.Idea); err != nil {
		return JSONResponse(http.StatusBadRequest, models.ErrorResponse{
			Error:   "VALIDATION_FAILED",
			Message: err.Error(),
		})
	}

	clientTs := payload.Timestamp
	if clientTs == 0 {
		clientTs = float64(time.Now().UnixNano()) / 1e6
	}
	serverTs := float64(time.Now().UnixNano()) / 1e6
	ideaID := uuid.New().String()

	idea := &models.Idea{
		ID:              ideaID,
		UserID:          user.ID,
		Idea:            payload.Idea,
		ClientTimestamp: clientTs,
		ServerTimestamp: serverTs,
	}

	if err := h.repo.CreateIdea(ctx, idea); err != nil {
		return JSONResponse(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "INTERNAL_ERROR",
			Message: "Failed to persist idea.",
		})
	}

	resp := models.IdeaSubmissionResponse{
		Success: true,
		ID:      ideaID,
		Message: "Idea successfully submitted.",
	}
	return JSONResponse(http.StatusCreated, resp)
}

// HandleListIdeas handles GET /api/ideas
func (h *IdeasHandler) HandleListIdeas(ctx context.Context, user *models.UserDTO) (events.APIGatewayProxyResponse, error) {
	items, err := h.repo.GetIdeasByUser(ctx, user.ID, user.Email)
	if err != nil {
		return JSONResponse(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "INTERNAL_ERROR",
			Message: "Failed to retrieve ideas.",
		})
	}

	dtoList := make([]models.IdeaItemDTO, 0, len(items))
	for _, it := range items {
		dtoList = append(dtoList, models.IdeaItemDTO{
			ID:              it.ID,
			Idea:            it.Idea,
			ClientTimestamp: it.ClientTimestamp,
			ServerTimestamp: it.ServerTimestamp,
		})
	}

	return JSONResponse(http.StatusOK, models.IdeaListResponse{
		Ideas: dtoList,
	})
}

// HandleGetIdea handles GET /api/ideas/{id} or direct ID probe
func (h *IdeasHandler) HandleGetIdea(ctx context.Context, ideaID string, user *models.UserDTO) (events.APIGatewayProxyResponse, error) {
	idea, err := h.repo.GetIdeaByID(ctx, ideaID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return JSONResponse(http.StatusNotFound, models.ErrorResponse{
				Error:   "NOT_FOUND",
				Message: "Idea not found.",
			})
		}
		return JSONResponse(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "INTERNAL_ERROR",
			Message: "Failed to fetch idea.",
		})
	}

	// Strictly verify that the idea belongs to the authenticated user.
	// Mask cross-user probes as 404 to avoid leaking existence or metadata.
	if idea.UserID != user.ID && (user.Email == "" || idea.UserID != user.Email) {
		return JSONResponse(http.StatusNotFound, models.ErrorResponse{
			Error:   "NOT_FOUND",
			Message: "Idea not found.",
		})
	}

	return JSONResponse(http.StatusOK, models.IdeaItemDTO{
		ID:              idea.ID,
		Idea:            idea.Idea,
		ClientTimestamp: idea.ClientTimestamp,
		ServerTimestamp: idea.ServerTimestamp,
	})
}
