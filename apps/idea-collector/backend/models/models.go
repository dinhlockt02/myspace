package models

import (
	"errors"
	"net/mail"
	"strings"
)

// User represents a user account record in IdeaCollector_Users
type User struct {
	Email           string  `dynamodbav:"email" json:"email"`
	ID              string  `dynamodbav:"id" json:"id"`
	GoogleSub       string  `dynamodbav:"google_sub,omitempty" json:"google_sub,omitempty"`
	Status          string  `dynamodbav:"status" json:"status"` // "invited" | "active" | "suspended"
	InvitedByUserID string  `dynamodbav:"invited_by_user_id,omitempty" json:"invited_by_user_id,omitempty"`
	CreatedAt       float64 `dynamodbav:"created_at" json:"created_at"`
	LastLoginAt     float64 `dynamodbav:"last_login_at,omitempty" json:"last_login_at,omitempty"`
}

// Session represents an active session record in IdeaCollector_Sessions
type Session struct {
	SessionID      string  `dynamodbav:"session_id" json:"session_id"`
	UserID         string  `dynamodbav:"user_id" json:"user_id"`
	Email          string  `dynamodbav:"email" json:"email"`
	CreatedAt      float64 `dynamodbav:"created_at" json:"created_at"`
	LastActivityAt float64 `dynamodbav:"last_activity_at" json:"last_activity_at"`
	ExpiresAt      int64   `dynamodbav:"expires_at" json:"expires_at"` // Epoch seconds for DynamoDB TTL
	IsValid        bool    `dynamodbav:"is_valid" json:"is_valid"`
}

// Idea represents an idea record in IdeaCollector_Ideas
type Idea struct {
	ID              string  `dynamodbav:"id" json:"id"`
	UserID          string  `dynamodbav:"user_id" json:"user_id"`
	Idea            string  `dynamodbav:"idea" json:"idea"`
	ClientTimestamp float64 `dynamodbav:"client_timestamp" json:"client_timestamp"`
	ServerTimestamp float64 `dynamodbav:"server_timestamp" json:"server_timestamp"`
}

// Request and Response DTOs

type GoogleAuthRequest struct {
	IDToken string `json:"id_token"`
}

type UserDTO struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name,omitempty"`
}

type AuthSessionResponse struct {
	SessionToken string  `json:"session_token"`
	ExpiresIn    int     `json:"expires_in"` // Seconds
	User         UserDTO `json:"user"`
}

type UserProfileResponse struct {
	User          UserDTO `json:"user"`
	IdleExpiresIn int     `json:"idle_expires_in"`
}

type LogoutResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type IdeaSubmissionRequest struct {
	Idea      string  `json:"idea"`
	Timestamp float64 `json:"timestamp"`
}

type IdeaSubmissionResponse struct {
	Success bool   `json:"success"`
	ID      string `json:"id"`
	Message string `json:"message"`
}

type IdeaItemDTO struct {
	ID              string  `json:"id"`
	Idea            string  `json:"idea"`
	ClientTimestamp float64 `json:"client_timestamp"`
	ServerTimestamp float64 `json:"server_timestamp"`
}

type IdeaListResponse struct {
	Ideas []IdeaItemDTO `json:"ideas"`
}

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

// Validation helpers

// ValidateIdea validates the idea content length (1 to 5,000 characters after trimming)
func ValidateIdea(content string) error {
	trimmed := strings.TrimSpace(content)
	if len(trimmed) < 1 {
		return errors.New("the idea field is required and cannot be empty or whitespace only")
	}
	if len(trimmed) > 5000 {
		return errors.New("the idea field must not exceed 5000 characters")
	}
	return nil
}

// ValidateAndNormalizeEmail verifies RFC 5322 syntax and returns normalized lowercase email
func ValidateAndNormalizeEmail(email string) (string, error) {
	trimmed := strings.TrimSpace(email)
	if trimmed == "" {
		return "", errors.New("email address is required")
	}
	parsed, err := mail.ParseAddress(trimmed)
	if err != nil {
		return "", errors.New("invalid email address format")
	}
	normalized := strings.ToLower(parsed.Address)
	return normalized, nil
}
