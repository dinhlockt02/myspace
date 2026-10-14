package auth

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/dinhloc/myspace/apps/idea-collector/backend/models"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/repository"
)

var (
	ErrSessionExpired   = errors.New("SESSION_EXPIRED")
	ErrSessionInvalid   = errors.New("SESSION_INVALID")
	ErrAccountSuspended = errors.New("ACCOUNT_SUSPENDED")
)

const IdleTimeoutMilliseconds = 3600 * 1000 // 1 hour in ms

type SessionManager struct {
	repo *repository.Repository
}

func NewSessionManager(repo *repository.Repository) *SessionManager {
	return &SessionManager{repo: repo}
}

// GenerateSessionToken produces a cryptographically secure 32-byte URL-safe base64 string
func GenerateSessionToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("failed to generate random token: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// CreateSession generates and persists a new session with 1-hour idle window
func (m *SessionManager) CreateSession(ctx context.Context, userID, email string) (*models.Session, error) {
	token, err := GenerateSessionToken()
	if err != nil {
		return nil, err
	}

	nowMs := float64(time.Now().UnixNano()) / 1e6
	ttlSeconds := time.Now().Unix() + 3600

	session := &models.Session{
		SessionID:      token,
		UserID:         userID,
		Email:          email,
		CreatedAt:      nowMs,
		LastActivityAt: nowMs,
		ExpiresAt:      ttlSeconds,
		IsValid:        true,
	}

	if err := m.repo.CreateSession(ctx, session); err != nil {
		return nil, fmt.Errorf("failed to persist session: %w", err)
	}

	return session, nil
}

// ValidateSession validates the token, enforces 1-hour idle timeout, verifies account status, and slides the window
func (m *SessionManager) ValidateSession(ctx context.Context, sessionID string) (*models.Session, error) {
	session, err := m.repo.GetSession(ctx, sessionID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrSessionInvalid
		}
		return nil, fmt.Errorf("session lookup error: %w", err)
	}

	if !session.IsValid {
		return nil, ErrSessionInvalid
	}

	nowMs := float64(time.Now().UnixNano()) / 1e6
	idleDurationMs := nowMs - session.LastActivityAt
	if idleDurationMs > IdleTimeoutMilliseconds {
		// Session has expired due to 1-hour idle inactivity
		_ = m.repo.InvalidateSession(ctx, sessionID)
		return nil, ErrSessionExpired
	}

	// Verify user account status (e.g. suspended accounts must be blocked immediately)
	user, err := m.repo.GetUserByEmail(ctx, session.Email)
	if err != nil {
		return nil, ErrSessionInvalid
	}
	if user.Status == "suspended" {
		_ = m.repo.InvalidateSession(ctx, sessionID)
		return nil, ErrAccountSuspended
	}

	// Slide idle window
	newTTLSeconds := time.Now().Unix() + 3600
	_ = m.repo.UpdateSessionActivity(ctx, sessionID, nowMs, newTTLSeconds)
	session.LastActivityAt = nowMs
	session.ExpiresAt = newTTLSeconds

	return session, nil
}

// InvalidateSession explicitly ends a session (logout)
func (m *SessionManager) InvalidateSession(ctx context.Context, sessionID string) error {
	return m.repo.InvalidateSession(ctx, sessionID)
}
