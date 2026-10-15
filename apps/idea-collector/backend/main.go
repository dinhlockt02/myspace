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
	authHandler    *handlers.AuthHandler
	ideasHandler   *handlers.IdeasHandler
	sessionManager *auth.SessionManager
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

	// Protected Routes - resolve authenticated user from Cognito JWT Authorizer or Bearer token
	user, err := extractUserFromRequest(ctx, req)
	if err != nil {
		return handlers.JSONResponse(http.StatusUnauthorized, models.ErrorResponse{
			Error:   "UNAUTHORIZED",
			Message: "Authentication required: " + err.Error(),
		})
	}

	switch {
	case req.HTTPMethod == "GET" && path == "/api/auth/me":
		return authHandler.HandleGetMe(ctx, user)

	case req.HTTPMethod == "POST" && path == "/api/auth/logout":
		return authHandler.HandleLogout(ctx, user)

	case req.HTTPMethod == "POST" && path == "/api/ideas":
		return ideasHandler.HandleSubmitIdea(ctx, req, user)

	case req.HTTPMethod == "GET" && path == "/api/ideas":
		return ideasHandler.HandleListIdeas(ctx, user)

	default:
		return handlers.JSONResponse(http.StatusNotFound, models.ErrorResponse{
			Error:   "NOT_FOUND",
			Message: "Route not found.",
		})
	}
}

func extractUserFromRequest(ctx context.Context, req events.APIGatewayProxyRequest) (*models.UserDTO, error) {
	// 1. Check API Gateway HTTP API v2 JWT Authorizer claims
	if req.RequestContext.Authorizer != nil {
		if jwtObj, ok := req.RequestContext.Authorizer["jwt"].(map[string]interface{}); ok {
			if claims, ok := jwtObj["claims"].(map[string]interface{}); ok {
				sub, _ := claims["sub"].(string)
				email, _ := claims["email"].(string)
				name, _ := claims["name"].(string)
				if sub != "" {
					return &models.UserDTO{
						ID:    sub,
						Email: email,
						Name:  name,
					}, nil
				}
			}
		}
		if sub, ok := req.RequestContext.Authorizer["sub"].(string); ok && sub != "" {
			email, _ := req.RequestContext.Authorizer["email"].(string)
			name, _ := req.RequestContext.Authorizer["name"].(string)
			return &models.UserDTO{
				ID:    sub,
				Email: email,
				Name:  name,
			}, nil
		}
	}

	// 2. Fallback to Bearer token lookup for backward compatibility and tests
	token := extractBearerToken(req)
	if token != "" && sessionManager != nil {
		session, err := sessionManager.ValidateSession(ctx, token)
		if err == nil && session != nil {
			return &models.UserDTO{
				ID:    session.UserID,
				Email: session.Email,
			}, nil
		}
		if errors.Is(err, auth.ErrSessionExpired) {
			return nil, errors.New("session has expired due to idle timeout")
		}
		if errors.Is(err, auth.ErrAccountSuspended) {
			return nil, errors.New("account suspended")
		}
	}

	return nil, errors.New("missing or invalid authorization credentials")
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
