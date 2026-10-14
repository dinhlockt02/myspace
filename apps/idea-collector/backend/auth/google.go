package auth

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"
)

const googleJWKSURL = "https://www.googleapis.com/oauth2/v3/certs"

type GoogleJWKS struct {
	Keys []GoogleJWK `json:"keys"`
}

type GoogleJWK struct {
	Kty string `json:"kty"`
	Alg string `json:"alg"`
	Use string `json:"use"`
	Kid string `json:"kid"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type GoogleTokenHeader struct {
	Alg string `json:"alg"`
	Kid string `json:"kid"`
}

type GoogleTokenPayload struct {
	Iss           string `json:"iss"`
	Sub           string `json:"sub"`
	Aud           string `json:"aud"`
	Exp           int64  `json:"exp"`
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
}

type GoogleTokenVerifier struct {
	expectedClientID string
	client           *http.Client
	mu               sync.RWMutex
	keysCache        map[string]*rsa.PublicKey
	keysExpiry       time.Time
}

func NewGoogleTokenVerifier(clientID string) *GoogleTokenVerifier {
	return &GoogleTokenVerifier{
		expectedClientID: clientID,
		client:           &http.Client{Timeout: 10 * time.Second},
		keysCache:        make(map[string]*rsa.PublicKey),
	}
}

func (v *GoogleTokenVerifier) VerifyIDToken(idToken string) (*GoogleTokenPayload, error) {
	parts := strings.Split(idToken, ".")
	if len(parts) != 3 {
		return nil, errors.New("invalid token format: must have 3 segments")
	}

	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, fmt.Errorf("failed to decode token header: %w", err)
	}

	var header GoogleTokenHeader
	if err := json.Unmarshal(headerBytes, &header); err != nil {
		return nil, fmt.Errorf("failed to parse token header: %w", err)
	}

	if header.Alg != "RS256" {
		return nil, fmt.Errorf("unsupported algorithm: %s, expected RS256", header.Alg)
	}

	pubKey, err := v.getKey(header.Kid)
	if err != nil {
		return nil, fmt.Errorf("failed to obtain verification key: %w", err)
	}

	// Verify signature: SHA256 of header + "." + payload
	signedContent := parts[0] + "." + parts[1]
	hash := sha256.Sum256([]byte(signedContent))

	sigBytes, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, fmt.Errorf("failed to decode signature: %w", err)
	}

	if err := rsa.VerifyPKCS1v15(pubKey, crypto.SHA256, hash[:], sigBytes); err != nil {
		return nil, fmt.Errorf("invalid token signature: %w", err)
	}

	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("failed to decode token payload: %w", err)
	}

	var payload GoogleTokenPayload
	if err := json.Unmarshal(payloadBytes, &payload); err != nil {
		return nil, fmt.Errorf("failed to parse token payload: %w", err)
	}

	// Validate claims
	if payload.Iss != "https://accounts.google.com" && payload.Iss != "accounts.google.com" {
		return nil, fmt.Errorf("invalid token issuer: %s", payload.Iss)
	}

	if v.expectedClientID != "" && payload.Aud != v.expectedClientID {
		return nil, fmt.Errorf("invalid audience: got %s, expected %s", payload.Aud, v.expectedClientID)
	}

	now := time.Now().Unix()
	if payload.Exp < now {
		return nil, errors.New("google token is expired")
	}

	if !payload.EmailVerified {
		return nil, errors.New("google email is not verified")
	}

	payload.Email = strings.ToLower(strings.TrimSpace(payload.Email))
	return &payload, nil
}

func (v *GoogleTokenVerifier) getKey(kid string) (*rsa.PublicKey, error) {
	v.mu.RLock()
	if key, found := v.keysCache[kid]; found && time.Now().Before(v.keysExpiry) {
		v.mu.RUnlock()
		return key, nil
	}
	v.mu.RUnlock()

	// Refresh keys
	v.mu.Lock()
	defer v.mu.Unlock()

	// Double-check after acquiring write lock
	if key, found := v.keysCache[kid]; found && time.Now().Before(v.keysExpiry) {
		return key, nil
	}

	resp, err := v.client.Get(googleJWKSURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch google jwks: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch google jwks, status: %d", resp.StatusCode)
	}

	var jwks GoogleJWKS
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return nil, fmt.Errorf("failed to decode google jwks: %w", err)
	}

	newCache := make(map[string]*rsa.PublicKey)
	for _, k := range jwks.Keys {
		if k.Kty != "RSA" {
			continue
		}
		nBytes, err := base64.RawURLEncoding.DecodeString(k.N)
		if err != nil {
			continue
		}
		eBytes, err := base64.RawURLEncoding.DecodeString(k.E)
		if err != nil {
			continue
		}

		n := new(big.Int).SetBytes(nBytes)
		var e int
		for _, b := range eBytes {
			e = (e << 8) | int(b)
		}

		pubKey := &rsa.PublicKey{
			N: n,
			E: e,
		}
		newCache[k.Kid] = pubKey
	}

	v.keysCache = newCache
	v.keysExpiry = time.Now().Add(1 * time.Hour)

	if key, found := v.keysCache[kid]; found {
		return key, nil
	}

	return nil, fmt.Errorf("key id %s not found in google jwks", kid)
}
