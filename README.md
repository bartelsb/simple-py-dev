# Local Development Environment

Scripts, code, and instructions to set you up for successful local dev.

## Pre-requisites

Before you start, you'll need something to deploy into. I like [minikube](https://minikube.sigs.k8s.io/docs/start).

## Supported Endpoints

- `GET /healthz` - Returns a health check status
  - Response: `{"status": "ok"}`

- `GET /version` - Returns the application version
  - Response: The value of the `APP_VERSION` environment variable, or `"unknown"` if not set