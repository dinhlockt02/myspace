package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/dinhloc/myspace/apps/idea-collector/backend/models"
)

var (
	ErrNotFound = errors.New("resource not found")
)

type Repository struct {
	client            *dynamodb.Client
	ideasTableName    string
	usersTableName    string
	sessionsTableName string
}

func NewRepository(client *dynamodb.Client, ideasTable, usersTable, sessionsTable string) *Repository {
	return &Repository{
		client:            client,
		ideasTableName:    ideasTable,
		usersTableName:    usersTable,
		sessionsTableName: sessionsTable,
	}
}

// User repository methods

func (r *Repository) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	out, err := r.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(r.usersTableName),
		Key: map[string]types.AttributeValue{
			"email": &types.AttributeValueMemberS{Value: email},
		},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	if out.Item == nil {
		return nil, ErrNotFound
	}
	var user models.User
	if err := attributevalue.UnmarshalMap(out.Item, &user); err != nil {
		return nil, fmt.Errorf("failed to unmarshal user: %w", err)
	}
	return &user, nil
}

func (r *Repository) CreateUser(ctx context.Context, user *models.User) error {
	av, err := attributevalue.MarshalMap(user)
	if err != nil {
		return fmt.Errorf("failed to marshal user: %w", err)
	}
	_, err = r.client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(r.usersTableName),
		Item:      av,
	})
	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}
	return nil
}

func (r *Repository) UpdateUserOnLogin(ctx context.Context, email, googleSub string, loginTime float64) error {
	_, err := r.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: aws.String(r.usersTableName),
		Key: map[string]types.AttributeValue{
			"email": &types.AttributeValueMemberS{Value: email},
		},
		UpdateExpression: aws.String("SET #status = :active, #sub = :sub, #last_login = :login_time"),
		ExpressionAttributeNames: map[string]string{
			"#status":     "status",
			"#sub":        "google_sub",
			"#last_login": "last_login_at",
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":active":     &types.AttributeValueMemberS{Value: "active"},
			":sub":        &types.AttributeValueMemberS{Value: googleSub},
			":login_time": &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", loginTime)},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to update user login info: %w", err)
	}
	return nil
}

// Session repository methods

func (r *Repository) CreateSession(ctx context.Context, session *models.Session) error {
	av, err := attributevalue.MarshalMap(session)
	if err != nil {
		return fmt.Errorf("failed to marshal session: %w", err)
	}
	_, err = r.client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(r.sessionsTableName),
		Item:      av,
	})
	if err != nil {
		return fmt.Errorf("failed to create session: %w", err)
	}
	return nil
}

func (r *Repository) GetSession(ctx context.Context, sessionID string) (*models.Session, error) {
	out, err := r.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(r.sessionsTableName),
		Key: map[string]types.AttributeValue{
			"session_id": &types.AttributeValueMemberS{Value: sessionID},
		},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	if out.Item == nil {
		return nil, ErrNotFound
	}
	var session models.Session
	if err := attributevalue.UnmarshalMap(out.Item, &session); err != nil {
		return nil, fmt.Errorf("failed to unmarshal session: %w", err)
	}
	return &session, nil
}

func (r *Repository) UpdateSessionActivity(ctx context.Context, sessionID string, lastActivity float64, expiresAt int64) error {
	_, err := r.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: aws.String(r.sessionsTableName),
		Key: map[string]types.AttributeValue{
			"session_id": &types.AttributeValueMemberS{Value: sessionID},
		},
		UpdateExpression: aws.String("SET #last_act = :act, #exp = :exp"),
		ExpressionAttributeNames: map[string]string{
			"#last_act": "last_activity_at",
			"#exp":      "expires_at",
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":act": &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", lastActivity)},
			":exp": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", expiresAt)},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to update session activity: %w", err)
	}
	return nil
}

func (r *Repository) InvalidateSession(ctx context.Context, sessionID string) error {
	_, err := r.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: aws.String(r.sessionsTableName),
		Key: map[string]types.AttributeValue{
			"session_id": &types.AttributeValueMemberS{Value: sessionID},
		},
		UpdateExpression: aws.String("SET #valid = :invalid"),
		ExpressionAttributeNames: map[string]string{
			"#valid": "is_valid",
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":invalid": &types.AttributeValueMemberBOOL{Value: false},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to invalidate session: %w", err)
	}
	return nil
}

// Idea repository methods

func (r *Repository) CreateIdea(ctx context.Context, idea *models.Idea) error {
	av, err := attributevalue.MarshalMap(idea)
	if err != nil {
		return fmt.Errorf("failed to marshal idea: %w", err)
	}
	_, err = r.client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(r.ideasTableName),
		Item:      av,
	})
	if err != nil {
		return fmt.Errorf("failed to put idea item: %w", err)
	}
	return nil
}

func (r *Repository) GetIdeasByUserID(ctx context.Context, userID string) ([]models.Idea, error) {
	out, err := r.client.Query(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(r.ideasTableName),
		IndexName:              aws.String("UserIdeasIndex"),
		KeyConditionExpression: aws.String("#uid = :uid"),
		ExpressionAttributeNames: map[string]string{
			"#uid": "user_id",
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":uid": &types.AttributeValueMemberS{Value: userID},
		},
		ScanIndexForward: aws.Bool(false), // Newest first (reverse chronological order)
	})
	if err != nil {
		return nil, fmt.Errorf("failed to query user ideas: %w", err)
	}

	var ideas []models.Idea
	if err := attributevalue.UnmarshalListOfMaps(out.Items, &ideas); err != nil {
		return nil, fmt.Errorf("failed to unmarshal ideas: %w", err)
	}
	return ideas, nil
}

func (r *Repository) GetIdeaByID(ctx context.Context, ideaID string) (*models.Idea, error) {
	out, err := r.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(r.ideasTableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: ideaID},
		},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get idea by id: %w", err)
	}
	if out.Item == nil {
		return nil, ErrNotFound
	}
	var idea models.Idea
	if err := attributevalue.UnmarshalMap(out.Item, &idea); err != nil {
		return nil, fmt.Errorf("failed to unmarshal idea: %w", err)
	}
	return &idea, nil
}
