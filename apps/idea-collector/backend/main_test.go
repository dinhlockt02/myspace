package main

import (
	"context"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

func requestWithAuthorizer(authorizer map[string]interface{}) events.APIGatewayProxyRequest {
	return events.APIGatewayProxyRequest{
		RequestContext: events.APIGatewayProxyRequestContext{Authorizer: authorizer},
	}
}

func TestExtractUserFromRequest_AuthorizerClaims(t *testing.T) {
	claims := map[string]interface{}{"sub": "user-1", "email": "a@example.com", "name": "A"}

	tests := []struct {
		name       string
		authorizer map[string]interface{}
	}{
		{"payload 1.0 claims", map[string]interface{}{"claims": claims}},
		{"payload 2.0 jwt.claims", map[string]interface{}{"jwt": map[string]interface{}{"claims": claims}}},
		{"flat authorizer context", claims},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			user, err := extractUserFromRequest(context.Background(), requestWithAuthorizer(tt.authorizer))
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if user.ID != "user-1" || user.Email != "a@example.com" || user.Name != "A" {
				t.Errorf("unexpected user: %+v", user)
			}
		})
	}
}

func TestExtractUserFromRequest_AccessTokenWithoutEmail(t *testing.T) {
	authorizer := map[string]interface{}{"claims": map[string]interface{}{"sub": "user-2", "client_id": "abc"}}
	user, err := extractUserFromRequest(context.Background(), requestWithAuthorizer(authorizer))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user.ID != "user-2" {
		t.Errorf("expected ID user-2, got %q", user.ID)
	}
}

func TestExtractUserFromRequest_NoCredentials(t *testing.T) {
	if _, err := extractUserFromRequest(context.Background(), requestWithAuthorizer(nil)); err == nil {
		t.Fatal("expected error when no credentials are present")
	}
	if _, err := extractUserFromRequest(context.Background(), requestWithAuthorizer(map[string]interface{}{"claims": map[string]interface{}{}})); err == nil {
		t.Fatal("expected error when claims have no subject")
	}
}
