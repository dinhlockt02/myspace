package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/auth"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/handlers"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/models"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/repository"
)

var (
	authHandler        *handlers.AuthHandler
	ideasHandler       *handlers.IdeasHandler
	invitationsHandler *handlers.InvitationsHandler
	sessionManager     *auth.SessionManager
)

func init() {
	ideasTable := os.Getenv("TABLE_NAME")
	if ideasTable == "" {
		ideasTable = "IdeaCollector_Ideas"
	}

	usersTable := os.Getenv("USERS_TABLE_NAME")
	if usersTable == "" {
		usersTable = "IdeaCollector_Users"
	}

	sessionsTable := os.Getenv("SESSIONS_TABLE_NAME")
	if sessionsTable == "" {
		sessionsTable = "IdeaCollector_Sessions"
	}

	googleClientID := os.Getenv("GOOGLE_CLIENT_ID")

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load AWS SDK config: %v", err)
	}

	dynamodbClient := dynamodb.NewFromConfig(cfg)
	repo := repository.NewRepository(dynamodbClient, ideasTable, usersTable, sessionsTable)
	verifier := auth.NewGoogleTokenVerifier(googleClientID)
	sessionManager = auth.NewSessionManager(repo)

	authHandler = handlers.NewAuthHandler(repo, verifier, sessionManager)
	ideasHandler = handlers.NewIdeasHandler(repo)
	invitationsHandler = handlers.NewInvitationsHandler(repo)
}

func handleRequest(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Handle CORS preflight
	if req.HTTPMethod == "OPTIONS" {
		return handlers.JSONResponse(http.StatusOK, map[string]bool{"ok": true})
	}

	path := req.Path
	if path == "" {
		path = req.RequestContext.Path
	}

	// Normalize trailing slash if present
	if len(path) > 1 && strings.HasSuffix(path, "/") {
		path = strings.TrimSuffix(path, "/")
	}

	// Public Routes
	if req.HTTPMethod == "POST" && path == "/api/auth/google" {
		return authHandler.HandleGoogleAuth(ctx, req)
	}

	// Protected Routes - require Authorization: Bearer <token>
	token := extractBearerToken(req)
	if token == "" {
		return handlers.JSONResponse(http.StatusUnauthorized, models.ErrorResponse{
			Error:   "UNAUTHORIZED",
			Message: "Authentication required. Bearer token missing.",
		})
	}

	session, err := sessionManager.ValidateSession(ctx, token)
	if err != nil {
		if errors.Is(err, auth.ErrSessionExpired) {
			return handlers.JSONResponse(http.StatusUnauthorized, models.ErrorResponse{
				Error:   "SESSION_EXPIRED",
				Message: "Session has expired due to 1-hour idle timeout. Please re-authenticate.",
			})
		}
		if errors.Is(err, auth.ErrAccountSuspended) {
			return handlers.JSONResponse(http.StatusForbidden, models.ErrorResponse{
				Error:   "ACCOUNT_SUSPENDED",
				Message: "Your account has been suspended.",
			})
		}
		return handlers.JSONResponse(http.StatusUnauthorized, models.ErrorResponse{
			Error:   "UNAUTHORIZED",
			Message: "Invalid or expired session.",
		})
	}

	switch {
	case req.HTTPMethod == "GET" && path == "/api/auth/me":
		return authHandler.HandleGetMe(ctx, session)

	case req.HTTPMethod == "POST" && path == "/api/auth/logout":
		return authHandler.HandleLogout(ctx, session)

	case req.HTTPMethod == "POST" && path == "/api/ideas":
		return ideasHandler.HandleSubmitIdea(ctx, req, session)

	case req.HTTPMethod == "GET" && path == "/api/ideas":
		return ideasHandler.HandleListIdeas(ctx, session)

	case req.HTTPMethod == "POST" && path == "/api/invitations":
		return invitationsHandler.HandleCreateInvitation(ctx, req, session)

	default:
		return handlers.JSONResponse(http.StatusNotFound, models.ErrorResponse{
			Error:   "NOT_FOUND",
			Message: "Route not found.",
		})
	}
}

func extractBearerToken(req events.APIGatewayProxyRequest) string {
	authHeader := req.Headers["Authorization"]
	if authHeader == "" {
		authHeader = req.Headers["authorization"]
	}
	if authHeader == "" {
		return ""
	}

	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) == 2 && strings.EqualFold(parts[0], "Bearer") {
		return strings.TrimSpace(parts[1])
	}
	return ""
}

func main() {
	lambda.Start(handleRequest)
}
