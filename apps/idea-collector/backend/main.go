package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/google/uuid"
)

var dynamodbClient *dynamodb.Client
var tableName string

func init() {
	tableName = os.Getenv("TABLE_NAME")
	if tableName == "" {
		tableName = "IdeaCollector_Ideas"
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	dynamodbClient = dynamodb.NewFromConfig(cfg)
}

type IdeaSubmissionRequest struct {
	Idea      string  `json:"idea"`
	Timestamp float64 `json:"timestamp"` // Unix time ms
}

type IdeaSubmissionResponse struct {
	Success bool   `json:"success"`
	ID      string `json:"id"`
	Message string `json:"message"`
}

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

func handleRequest(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	if req.HTTPMethod != "POST" {
		return errorResponse(http.StatusMethodNotAllowed, "Method not allowed", "Only POST method is supported.")
	}

	var payload IdeaSubmissionRequest
	if err := json.Unmarshal([]byte(req.Body), &payload); err != nil {
		return errorResponse(http.StatusBadRequest, "Invalid JSON", "Could not parse request body.")
	}

	// Validation logic (T009)
	if len(payload.Idea) < 1 || len(payload.Idea) > 5000 {
		return errorResponse(http.StatusBadRequest, "Validation failed", "The 'idea' field is required and must not exceed 5000 characters.")
	}

	if payload.Timestamp == 0 {
		return errorResponse(http.StatusBadRequest, "Validation failed", "The 'timestamp' field is required.")
	}

	// T011: Map data model and PutItem
	id := uuid.New().String()
	serverTimestamp := float64(time.Now().UnixNano()) / 1e6 // in milliseconds

	item := map[string]types.AttributeValue{
		"id":               &types.AttributeValueMemberS{Value: id},
		"idea":             &types.AttributeValueMemberS{Value: payload.Idea},
		"client_timestamp": &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", payload.Timestamp)},
		"server_timestamp": &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", serverTimestamp)},
	}

	_, err := dynamodbClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: &tableName,
		Item:      item,
	})

	if err != nil {
		log.Printf("Failed to put item into dynamodb: %v", err)
		return errorResponse(http.StatusInternalServerError, "Internal Server Error", "Could not save the idea.")
	}

	// T012: Return 201 Created
	resp := IdeaSubmissionResponse{
		Success: true,
		ID:      id,
		Message: "Idea successfully submitted.",
	}
	respBody, _ := json.Marshal(resp)

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusCreated,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(respBody),
	}, nil
}

func errorResponse(statusCode int, errType, message string) (events.APIGatewayProxyResponse, error) {
	resp := ErrorResponse{
		Error:   errType,
		Message: message,
	}
	body, _ := json.Marshal(resp)

	return events.APIGatewayProxyResponse{
		StatusCode: statusCode,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(body),
	}, nil
}

func main() {
	lambda.Start(handleRequest)
}
