# idea-collector

A simple web application to collect ideas.

## Architecture

- **Frontend**: React app with a form to submit ideas
- **Backend**: AWS Lambda (Go) to process submissions
- **Infra**: Terraform + AWS (API Gateway + Lambda)

## Structure

```
apps/idea-collector/
├── frontend/    # React frontend
├── backend/     # AWS Lambda functions
└── deploy/      # Terraform infrastructure
```

## Development

```bash
cd frontend && npm install && npm run dev
cd backend && go build ./...
```

## Deployment

```bash
cd deploy && terraform apply
```
