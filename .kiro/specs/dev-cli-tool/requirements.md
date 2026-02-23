# Requirements Document

## Introduction

A bash CLI tool (dev.sh) that provides a unified interface for managing Docker builds, Terraform deployments, and Kubernetes operations for a demo application. The tool simplifies common development workflows by wrapping Docker, Terraform, and kubectl commands with sensible defaults and interactive prompts.

## Glossary

- **CLI_Tool**: The dev.sh bash script that provides the command-line interface
- **Environment**: A deployment target (e.g., "local", "staging", "production")
- **Workspace**: A Terraform workspace used as a version identifier
- **Version**: An identifier for a specific deployment, implemented as a Terraform workspace name
- **App**: The application being managed (default: "demo-app")
- **Container_Image**: A Docker image tagged with format `<app>:<version>`
- **Port_Forwarding**: A kubectl port-forward connection to a Kubernetes service
- **Deployment_Status**: Whether a version is currently deployed in Kubernetes

## Requirements

### Requirement 1: Environment Provisioning

**User Story:** As a developer, I want to provision infrastructure for a specific version, so that I can deploy and test my application.

#### Acceptance Criteria

1. WHEN the user executes the "up" command, THE CLI_Tool SHALL create or select the specified Terraform workspace
2. WHEN the user executes the "up" command, THE CLI_Tool SHALL run terraform apply in the appropriate infrastructure directory
3. WHERE no version is specified, THE CLI_Tool SHALL prompt the user to enter a version name
4. WHERE no environment is specified, THE CLI_Tool SHALL use "local" as the default environment
5. WHERE no app is specified, THE CLI_Tool SHALL use "demo-app" as the default app
6. WHEN terraform apply completes successfully, THE CLI_Tool SHALL display the terraform output

### Requirement 2: Environment Teardown

**User Story:** As a developer, I want to destroy infrastructure for a specific version, so that I can clean up resources I no longer need.

#### Acceptance Criteria

1. WHEN the user executes the "down" command, THE CLI_Tool SHALL select the specified Terraform workspace
2. WHEN the user executes the "down" command, THE CLI_Tool SHALL run terraform destroy in the appropriate infrastructure directory
3. WHERE no version is specified, THE CLI_Tool SHALL prompt the user to enter a version name
4. WHERE no environment is specified, THE CLI_Tool SHALL use "local" as the default environment
5. WHERE no app is specified, THE CLI_Tool SHALL use "demo-app" as the default app
6. WHEN terraform destroy completes successfully, THE CLI_Tool SHALL display a confirmation message

### Requirement 3: Container Image Building

**User Story:** As a developer, I want to build Docker images for my application, so that I can deploy specific versions.

#### Acceptance Criteria

1. WHEN the user executes the "build" command, THE CLI_Tool SHALL build a Docker image from the Dockerfile at `<app>/src/Dockerfile`
2. WHERE no tag is specified, THE CLI_Tool SHALL use the last 8 characters of the current git commit hash as the image tag
3. WHERE a tag is specified with `-t` or `--tag`, THE CLI_Tool SHALL use the specified tag for the image
4. WHEN the build completes, THE CLI_Tool SHALL tag the image with format `<app>:<tag>`
5. WHERE no app is specified, THE CLI_Tool SHALL use "demo-app" as the default app
6. WHEN the build fails, THE CLI_Tool SHALL display the Docker build error and exit with a non-zero status

### Requirement 4: Build and Deploy

**User Story:** As a developer, I want to build and deploy in a single command, so that I can streamline my workflow.

#### Acceptance Criteria

1. WHEN the user executes "build" with the `-d` or `--deploy` flag, THE CLI_Tool SHALL first build the Docker image
2. WHEN the build succeeds with the deploy flag, THE CLI_Tool SHALL execute the same logic as the "up" command
3. WHEN the build fails with the deploy flag, THE CLI_Tool SHALL not proceed to deployment
4. WHEN deploying after build, THE CLI_Tool SHALL pass the built image tag as the container_image variable to Terraform

### Requirement 5: Version Listing

**User Story:** As a developer, I want to see all available versions and their deployment status, so that I can understand what is currently running.

#### Acceptance Criteria

1. WHEN the user executes the "versions" command, THE CLI_Tool SHALL list all Terraform workspaces for the specified environment
2. WHEN listing versions, THE CLI_Tool SHALL query Kubernetes to determine which versions are currently deployed
3. WHEN listing versions, THE CLI_Tool SHALL display the local URL for deployed versions that have active port-forwarding
4. WHERE no environment is specified, THE CLI_Tool SHALL use "local" as the default environment
5. WHERE no app is specified, THE CLI_Tool SHALL use "demo-app" as the default app
6. WHEN displaying versions, THE CLI_Tool SHALL format the output to clearly show workspace name, deployment status, and local URL for active port-forwards

### Requirement 6: Log Viewing

**User Story:** As a developer, I want to view logs for a specific version, so that I can debug issues and monitor application behavior.

#### Acceptance Criteria

1. WHEN the user executes the "logs" command, THE CLI_Tool SHALL retrieve logs from the Kubernetes pod for the specified version
2. WHERE no version is specified, THE CLI_Tool SHALL prompt the user to enter a version name
3. WHERE the `-f` or `--follow` flag is specified, THE CLI_Tool SHALL stream logs continuously using `kubectl logs -f`
4. WHERE no environment is specified, THE CLI_Tool SHALL use "local" as the default environment
5. WHERE no app is specified, THE CLI_Tool SHALL use "demo-app" as the default app
6. WHEN the specified version is not deployed, THE CLI_Tool SHALL display an error message and exit with a non-zero status

### Requirement 7: Port Forwarding

**User Story:** As a developer, I want to set up port-forwarding to a specific version, so that I can access the application locally.

#### Acceptance Criteria

1. WHEN the user executes the "expose" command with a port specified, THE CLI_Tool SHALL set up kubectl port-forward to the specified version
2. WHERE no version is specified, THE CLI_Tool SHALL prompt the user to enter a version name
3. WHEN the `-p` or `--port` flag is not provided, THE CLI_Tool SHALL display an error message indicating the port is required
4. WHERE no environment is specified, THE CLI_Tool SHALL use "local" as the default environment
5. WHERE no app is specified, THE CLI_Tool SHALL use "demo-app" as the default app
6. WHEN port-forwarding is established, THE CLI_Tool SHALL display the local URL and keep the connection active
7. WHEN the specified version is not deployed, THE CLI_Tool SHALL display an error message and exit with a non-zero status

### Requirement 8: Global Options Handling

**User Story:** As a developer, I want to override default values for app, environment, and version, so that I can work with different configurations.

#### Acceptance Criteria

1. WHEN the user specifies `-a` or `--app`, THE CLI_Tool SHALL use the specified app name instead of the default
2. WHEN the user specifies `-e` or `--environment`, THE CLI_Tool SHALL use the specified environment instead of the default
3. WHEN the user specifies `-v` or `--version`, THE CLI_Tool SHALL use the specified version instead of prompting
4. WHEN the user specifies `-h` or `--help`, THE CLI_Tool SHALL display usage information and exit
5. THE CLI_Tool SHALL parse global options before command-specific options
6. WHEN invalid options are provided, THE CLI_Tool SHALL display an error message and usage information

### Requirement 9: Tool Validation

**User Story:** As a developer, I want to be notified if required tools are missing, so that I can install them before attempting operations.

#### Acceptance Criteria

1. WHEN the CLI_Tool starts, THE CLI_Tool SHALL verify that docker is installed and accessible
2. WHEN the CLI_Tool starts, THE CLI_Tool SHALL verify that terraform is installed and accessible
3. WHEN the CLI_Tool starts, THE CLI_Tool SHALL verify that kubectl is installed and accessible
4. WHEN the CLI_Tool starts, THE CLI_Tool SHALL verify that git is installed and accessible
5. WHEN any required tool is missing, THE CLI_Tool SHALL display an error message indicating which tool is missing
6. WHEN any required tool is missing, THE CLI_Tool SHALL exit with a non-zero status before attempting any operations

### Requirement 10: Error Handling

**User Story:** As a developer, I want clear error messages when operations fail, so that I can understand and fix problems quickly.

#### Acceptance Criteria

1. WHEN a Docker command fails, THE CLI_Tool SHALL display the error output and exit with a non-zero status
2. WHEN a Terraform command fails, THE CLI_Tool SHALL display the error output and exit with a non-zero status
3. WHEN a kubectl command fails, THE CLI_Tool SHALL display the error output and exit with a non-zero status
4. WHEN a git command fails, THE CLI_Tool SHALL display the error output and exit with a non-zero status
5. WHEN an invalid command is provided, THE CLI_Tool SHALL display an error message and usage information
6. WHEN required arguments are missing, THE CLI_Tool SHALL display an error message indicating what is missing

### Requirement 11: Cross-Platform Compatibility

**User Story:** As a developer using Windows, I want the tool to work in my bash shell, so that I can use the same workflow as other team members.

#### Acceptance Criteria

1. THE CLI_Tool SHALL use bash syntax compatible with Windows bash shells (Git Bash, WSL)
2. THE CLI_Tool SHALL use forward slashes for path separators that work across platforms
3. THE CLI_Tool SHALL avoid platform-specific commands that are not available in Windows bash environments
4. WHEN running on Windows, THE CLI_Tool SHALL execute Docker, Terraform, and kubectl commands successfully

### Requirement 12: Infrastructure Path Resolution

**User Story:** As a developer, I want the tool to automatically find the correct infrastructure directory, so that I don't have to specify paths manually.

#### Acceptance Criteria

1. WHEN executing terraform commands, THE CLI_Tool SHALL construct the path as `<app>/infrastructure/<environment>/`
2. WHEN the infrastructure directory does not exist, THE CLI_Tool SHALL display an error message and exit with a non-zero status
3. WHEN executing terraform commands, THE CLI_Tool SHALL change to the infrastructure directory before running terraform
4. WHEN terraform commands complete, THE CLI_Tool SHALL return to the original working directory

### Requirement 13: Kubernetes Namespace Resolution

**User Story:** As a developer, I want the tool to automatically determine the correct Kubernetes namespace, so that operations target the right resources.

#### Acceptance Criteria

1. WHEN executing kubectl commands, THE CLI_Tool SHALL construct the namespace as `<app>-<version>`
2. WHEN querying deployment status, THE CLI_Tool SHALL check for resources in the namespace `<app>-<version>`
3. WHEN the namespace does not exist, THE CLI_Tool SHALL treat the version as not deployed

### Requirement 14: Terraform Variable Passing

**User Story:** As a developer, I want the tool to pass the correct variables to Terraform, so that infrastructure is provisioned with the right configuration.

#### Acceptance Criteria

1. WHEN running terraform apply, THE CLI_Tool SHALL pass the environment variable with `-var="environment=<environment>"`
2. WHEN running terraform apply, THE CLI_Tool SHALL pass the app_version variable with `-var="app_version=<version>"`
3. WHEN running terraform apply, THE CLI_Tool SHALL pass the container_image variable with `-var="container_image=<app>:<version>"`
4. WHEN running terraform destroy, THE CLI_Tool SHALL pass the same variables as terraform apply
