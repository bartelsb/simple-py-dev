# Design Document: dev.sh CLI Tool

## Overview

The dev.sh CLI tool is a bash script that provides a unified interface for managing Docker builds, Terraform deployments, and Kubernetes operations. The tool wraps common development workflows with sensible defaults, interactive prompts, and proper error handling.

The design follows a modular approach with separate functions for each command, shared utility functions for common operations (argument parsing, tool validation, path resolution), and consistent error handling throughout.

## Architecture

The tool follows a command-dispatch architecture:

```
dev.sh
├── Initialization & Validation
│   ├── Check required tools (docker, terraform, kubectl, git)
│   └── Parse global options
├── Command Dispatcher
│   ├── up → cmd_up()
│   ├── down → cmd_down()
│   ├── build → cmd_build()
│   ├── versions → cmd_versions()
│   ├── logs → cmd_logs()
│   └── expose → cmd_expose()
└── Utility Functions
    ├── parse_args()
    ├── validate_tools()
    ├── prompt_version()
    ├── get_infra_path()
    ├── get_namespace()
    ├── get_git_hash()
    └── error_exit()
```

### Control Flow

1. Script starts → validate required tools
2. Parse global options (--app, --environment, --version, --help)
3. Dispatch to command function based on first positional argument
4. Command function parses command-specific options
5. Command function prompts for missing required values
6. Command function executes operations with error handling
7. Exit with appropriate status code

## Components and Interfaces

### Main Entry Point

```bash
#!/usr/bin/env bash
set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Global defaults
DEFAULT_APP="demo-app"
DEFAULT_ENV="local"

# Global variables (set by parse_args)
APP=""
ENVIRONMENT=""
VERSION=""

main() {
    validate_tools
    parse_global_args "$@"
    
    local command="${1:-}"
    shift || true
    
    case "$command" in
        up) cmd_up "$@" ;;
        down) cmd_down "$@" ;;
        build) cmd_build "$@" ;;
        versions) cmd_versions "$@" ;;
        logs) cmd_logs "$@" ;;
        expose) cmd_expose "$@" ;;
        -h|--help|help) show_help ;;
        "") error_exit "No command specified. Use --help for usage." ;;
        *) error_exit "Unknown command: $command" ;;
    esac
}

main "$@"
```

### Tool Validation

```bash
validate_tools() {
    local missing_tools=()
    
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v git >/dev/null 2>&1 || missing_tools+=("git")
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        error_exit "Missing required tools: ${missing_tools[*]}"
    fi
}
```

### Argument Parsing

```bash
parse_global_args() {
    APP="$DEFAULT_APP"
    ENVIRONMENT="$DEFAULT_ENV"
    VERSION=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--app)
                APP="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                # Not a global option, stop parsing
                break
                ;;
        esac
    done
}
```

### Utility Functions

```bash
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

prompt_version() {
    if [ -z "$VERSION" ]; then
        read -p "Enter version name: " VERSION
        [ -z "$VERSION" ] && error_exit "Version is required"
    fi
}

get_infra_path() {
    local path="${APP}/infrastructure/${ENVIRONMENT}"
    [ -d "$path" ] || error_exit "Infrastructure directory not found: $path"
    echo "$path"
}

get_namespace() {
    echo "${APP}$-${VERSION}"
}

get_git_hash() {
    git rev-parse --short=8 HEAD 2>/dev/null || error_exit "Failed to get git commit hash"
}

is_deployed() {
    local namespace=$(get_namespace)
    kubectl get namespace "$namespace" >/dev/null 2>&1
}

get_port_forward_info() {
    local namespace=$(get_namespace)
    # Find active port-forward process and extract local port
    local pf_line=$(ps aux | grep "kubectl.*port-forward.*$namespace" | grep -v grep | head -n 1)
    
    if [ -z "$pf_line" ]; then
        echo ""
        return
    fi
    
    # Extract local port from command line (format: kubectl port-forward ... 2717:8080)
    local port_mapping=$(echo "$pf_line" | grep -oP '\d+:\d+' | head -n 1)
    local local_port=$(echo "$port_mapping" | cut -d: -f1)
    
    if [ -n "$local_port" ]; then
        echo "http://localhost:${local_port}"
    fi
}
```

### Command: up

```bash
cmd_up() {
    prompt_version
    
    local infra_path=$(get_infra_path)
    local container_image="${APP}:${VERSION}"
    
    echo "Provisioning infrastructure for ${APP} version ${VERSION} in ${ENVIRONMENT}..."
    
    cd "$infra_path" || error_exit "Failed to change to infrastructure directory"
    
    # Initialize terraform
    terraform init || error_exit "Terraform init failed"
    
    # Create or select workspace
    terraform workspace select "$VERSION" 2>/dev/null || terraform workspace new "$VERSION"
    
    # Run terraform apply
    terraform apply \
        -var="environment=${ENVIRONMENT}" \
        -var="app_version=${VERSION}" \
        -var="container_image=${container_image}" \
        || error_exit "Terraform apply failed"
    
    cd - >/dev/null
    echo "Infrastructure provisioned successfully"
}
```

### Command: down

```bash
cmd_down() {
    prompt_version
    
    local infra_path=$(get_infra_path)
    local container_image="${APP}:${VERSION}"
    
    echo "Destroying infrastructure for ${APP} version ${VERSION} in ${ENVIRONMENT}..."
    
    cd "$infra_path" || error_exit "Failed to change to infrastructure directory"
    
    # Initialize terraform
    terraform init || error_exit "Terraform init failed"
    
    # Select workspace
    terraform workspace select "$VERSION" || error_exit "Workspace $VERSION not found"
    
    # Run terraform destroy
    terraform destroy \
        -var="environment=${ENVIRONMENT}" \
        -var="app_version=${VERSION}" \
        -var="container_image=${container_image}" \
        || error_exit "Terraform destroy failed"
    
    cd - >/dev/null
    echo "Infrastructure destroyed successfully"
}
```

### Command: build

```bash
cmd_build() {
    local tag=""
    local deploy=false
    
    # Parse command-specific options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--tag)
                tag="$2"
                shift 2
                ;;
            -d|--deploy)
                deploy=true
                shift
                ;;
            *)
                error_exit "Unknown option for build: $1"
                ;;
        esac
    done
    
    # Default tag to git hash if not specified
    if [ -z "$tag" ]; then
        tag=$(get_git_hash)
    fi
    
    local dockerfile="${APP}/src/Dockerfile"
    [ -f "$dockerfile" ] || error_exit "Dockerfile not found: $dockerfile"
    
    local image_name="${APP}:${tag}"
    
    echo "Building Docker image: $image_name"
    docker build -t "$image_name" -f "$dockerfile" "${APP}/src" \
        || error_exit "Docker build failed"
    
    echo "Image built successfully: $image_name"
    
    if [ "$deploy" = true ]; then
        echo "Deploying built image..."
        VERSION="$tag"
        cmd_up
    fi
}
```

### Command: versions

```bash
cmd_versions() {
    local infra_path=$(get_infra_path)
    
    echo "Versions for ${APP} in ${ENVIRONMENT}:"
    echo "----------------------------------------"
    
    cd "$infra_path" || error_exit "Failed to change to infrastructure directory"
    
    # Get all workspaces
    local workspaces=$(terraform workspace list | sed 's/^[* ] //')
    
    for workspace in $workspaces; do
        if [ "$workspace" = "default" ]; then
            continue
        fi
        
        VERSION="$workspace"
        local status="not deployed"
        local port_forward_info=""
        
        if is_deployed; then
            status="deployed"
            local pf_url=$(get_port_forward_info)
            if [ -n "$pf_url" ]; then
                port_forward_info=" → ${pf_url}"
            fi
        fi
        
        printf "  %-20s %s%s\n" "$workspace" "$status" "$port_forward_info"
    done
    
    cd - >/dev/null
}
```

### Command: logs

```bash
cmd_logs() {
    local follow=false
    
    # Parse command-specific options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--follow)
                follow=true
                shift
                ;;
            *)
                error_exit "Unknown option for logs: $1"
                ;;
        esac
    done
    
    prompt_version
    
    is_deployed || error_exit "Version $VERSION is not deployed"
    
    local namespace=$(get_namespace)
    
    echo "Fetching logs for ${APP} version ${VERSION}..."
    
    if [ "$follow" = true ]; then
        kubectl logs -f -n "$namespace" -l app="$APP" --all-containers=true
    else
        kubectl logs -n "$namespace" -l app="$APP" --all-containers=true
    fi
}
```

### Command: expose

```bash
cmd_expose() {
    local port=""
    
    # Parse command-specific options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--port)
                port="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown option for expose: $1"
                ;;
        esac
    done
    
    [ -z "$port" ] && error_exit "Port is required. Use -p or --port to specify."
    
    prompt_version
    
    is_deployed || error_exit "Version $VERSION is not deployed"
    
    local namespace=$(get_namespace)
    
    echo "Setting up port-forwarding for ${APP} version ${VERSION}..."
    echo "Access the application at: http://localhost:${port}"
    
    kubectl port-forward -n "$namespace" "svc/${APP}" "${port}:80"
}
```

### Help Text

```bash
show_help() {
    cat << EOF
dev.sh - Docker, Terraform, and Kubernetes management tool

Usage: dev.sh [global options] <command> [command options]

Global Options:
  -a, --app <app>           Specify application (default: demo-app)
  -e, --environment <env>   Specify environment (default: local)
  -v, --version <version>   Specify version/workspace name
  -h, --help                Show this help text

Commands:
  up                        Provision infrastructure with terraform apply
  down                      Destroy infrastructure with terraform destroy
  build                     Build Docker image
    -t, --tag <tag>         Tag for the image (default: latest git commit hash)
    -d, --deploy            Build and deploy in one step
  versions                  List all versions and their deployment status
  logs                      Show logs for a version
    -f, --follow            Follow logs live
  expose                    Set up port-forwarding to a version
    -p, --port <port>       Port to forward (required)

Examples:
  dev.sh up -v v1.0.0
  dev.sh build -t v1.0.0 -d
  dev.sh logs -v v1.0.0 -f
  dev.sh expose -v v1.0.0 -p 8080
  dev.sh versions
  dev.sh down -v v1.0.0
EOF
}
```

## Data Models

### Global State

The script maintains global state through bash variables:

```bash
# Set by argument parsing
APP=""           # Application name
ENVIRONMENT=""   # Deployment environment
VERSION=""       # Version/workspace identifier

# Constants
DEFAULT_APP="demo-app"
DEFAULT_ENV="local"
```

### Derived Values

Values computed from global state:

- **Infrastructure Path**: `${APP}/infrastructure/${ENVIRONMENT}/`
- **Kubernetes Namespace**: `demo-app-${VERSION}`
- **Container Image**: `${APP}:${VERSION}`
- **Git Hash**: Last 8 characters of current commit (for default tag)

### External State

The tool queries and modifies external state:

- **Terraform Workspaces**: List of version identifiers
- **Kubernetes Namespaces**: Indicates deployed versions
- **Port-Forward Processes**: Active kubectl port-forward processes
- **Docker Images**: Built container images


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, several patterns of redundancy emerged:

1. **Default value properties**: Multiple requirements test that defaults are "demo-app" and "local" - these can be consolidated into single properties
2. **Argument parsing properties**: Testing `-a`, `-e`, `-v` flags can be combined into a general argument parsing property
3. **Path construction properties**: Infrastructure path and namespace construction follow similar patterns
4. **Terraform variable passing**: All variable passing can be tested together rather than separately
5. **Error handling examples**: Most error cases are specific examples rather than universal properties

The following properties represent the unique, non-redundant correctness guarantees:

### Property 1: Workspace Management for Up Command

*For any* valid version name, when executing the "up" command, the tool should create the workspace if it doesn't exist, or select it if it does, before running terraform apply.

**Validates: Requirements 1.1**

### Property 2: Workspace Selection for Down Command

*For any* valid version name, when executing the "down" command, the tool should select the specified workspace before running terraform destroy.

**Validates: Requirements 2.1**

### Property 3: Dockerfile Path Construction

*For any* valid app name, when executing the "build" command, the tool should construct the Dockerfile path as `<app>/src/Dockerfile`.

**Validates: Requirements 3.1**

### Property 4: Image Tag Override

*For any* specified tag value, when executing the "build" command with `-t` or `--tag`, the tool should use that tag instead of the git hash.

**Validates: Requirements 3.3**

### Property 5: Image Naming Format

*For any* app name and tag combination, the built Docker image should be named with the format `<app>:<tag>`.

**Validates: Requirements 3.4**

### Property 6: Deploy Logic Consistency

*For any* version, when executing "build --deploy", the terraform commands invoked should be identical to those invoked by the "up" command with the same version.

**Validates: Requirements 4.2**

### Property 7: Container Image Variable Passing

*For any* app and version combination, when deploying after build, the container_image variable passed to terraform should equal `<app>:<version>`.

**Validates: Requirements 4.4**

### Property 8: Workspace Listing

*For any* set of terraform workspaces in an environment, the "versions" command should list all non-default workspaces.

**Validates: Requirements 5.1**

### Property 9: Deployment Status Detection

*For any* version, the "versions" command should correctly identify whether that version is deployed by checking for the existence of its Kubernetes namespace.

**Validates: Requirements 5.2**

### Property 10: Port-Forward URL Display

*For any* deployed version with active port-forwarding, the "versions" command should display the local URL (http://localhost:<local_port>) where the application can be accessed.

**Validates: Requirements 5.3**

### Property 11: Version Output Formatting

*For any* version, the "versions" command output should include the workspace name, deployment status, and local URL for active port-forwards.

**Validates: Requirements 5.6**

### Property 12: Logs Namespace Targeting

*For any* version, the "logs" command should retrieve logs from the namespace `demo-app-<version>` using the correct app label.

**Validates: Requirements 6.1**

### Property 13: Port-Forward Command Construction

*For any* valid port number and version, the "expose" command should invoke kubectl port-forward with the correct namespace and service name.

**Validates: Requirements 7.1**

### Property 14: App Argument Parsing

*For any* app name specified with `-a` or `--app`, the tool should use that app name instead of the default throughout execution.

**Validates: Requirements 8.1**

### Property 15: Environment Argument Parsing

*For any* environment name specified with `-e` or `--environment`, the tool should use that environment instead of the default throughout execution.

**Validates: Requirements 8.2**

### Property 16: Version Argument Parsing

*For any* version name specified with `-v` or `--version`, the tool should use that version and skip prompting.

**Validates: Requirements 8.3**

### Property 17: Global Options Parsing Order

*For any* combination of global options and commands, global options should be parsed before command-specific options, regardless of their position before the command name.

**Validates: Requirements 8.5**

### Property 18: Path Separator Consistency

*For all* constructed paths (infrastructure paths, Dockerfile paths), the tool should use forward slashes as path separators.

**Validates: Requirements 11.2**

### Property 19: Infrastructure Path Construction

*For any* app and environment combination, the infrastructure path should be constructed as `<app>/infrastructure/<environment>/`.

**Validates: Requirements 12.1**

### Property 20: Working Directory Management for Terraform

*For any* terraform command execution, the tool should change to the infrastructure directory before running terraform and return to the original directory after completion.

**Validates: Requirements 12.3, 12.4**

### Property 21: Namespace Construction

*For any* version, when executing kubectl commands, the namespace should be constructed as `demo-app-<version>`.

**Validates: Requirements 13.1**

### Property 22: Namespace Usage in Deployment Queries

*For any* version, when querying deployment status, the tool should check for the namespace `demo-app-<version>`.

**Validates: Requirements 13.2**

### Property 23: Terraform Variable Passing for Apply

*For any* app, environment, and version combination, when running terraform apply, the tool should pass all three variables: `environment=<environment>`, `app_version=<version>`, and `container_image=<app>:<version>`.

**Validates: Requirements 14.1, 14.2, 14.3**

### Property 24: Terraform Variable Consistency

*For any* app, environment, and version combination, the variables passed to terraform destroy should be identical to those passed to terraform apply.

**Validates: Requirements 14.4**

## Error Handling

The tool implements comprehensive error handling at multiple levels:

### Tool Validation Errors

- Missing required tools (docker, terraform, kubectl, git) are detected at startup
- Error message format: "Missing required tools: <tool1> <tool2> ..."
- Exit code: Non-zero
- **Validates: Requirements 9.1-9.6**

### Command Execution Errors

- Docker build failures display error output and exit with non-zero status
- Terraform apply/destroy failures display error output and exit with non-zero status
- kubectl command failures display error output and exit with non-zero status
- Git command failures display error output and exit with non-zero status
- **Validates: Requirements 10.1-10.4**

### Input Validation Errors

- Invalid commands display error message and usage information
- Missing required arguments (e.g., port for expose) display specific error messages
- Invalid options display error message and usage information
- **Validates: Requirements 10.5, 10.6, 7.3, 8.6**

### Resource Validation Errors

- Non-existent infrastructure directories display error and exit
- Non-existent Dockerfile displays error and exit
- Non-deployed versions (for logs/expose) display error and exit
- Non-existent workspaces (for down) display error and exit
- **Validates: Requirements 12.2, 3.6, 6.6, 7.7**

### Error Handling Implementation

All errors use the `error_exit()` utility function:

```bash
error_exit() {
    echo "Error: $1" >&2
    exit 1
}
```

This ensures:
- Consistent error message format
- Error output to stderr
- Non-zero exit status
- Immediate termination (via `set -e`)

## Testing Strategy

### Manual Testing Approach

The dev.sh CLI tool will be tested manually through real-world usage scenarios. No automated test files will be created.

### Manual Test Scenarios

Manual testing should verify:

1. **Command execution**:
   - Each command (up, down, build, versions, logs, expose) works correctly
   - Default values are applied when options are omitted
   - Specified options override defaults correctly

2. **Error handling**:
   - Missing tools are detected and reported
   - Invalid commands display helpful error messages
   - Missing required arguments are caught
   - Non-existent resources (directories, workspaces, deployments) are handled gracefully

3. **Integration with external tools**:
   - Docker builds execute successfully
   - Terraform workspace operations work correctly
   - kubectl commands target the right namespaces
   - Git hash retrieval works

4. **Cross-platform compatibility**:
   - Script runs on Linux/macOS bash
   - Script runs on Windows (Git Bash, WSL)

### Testing Checklist

Before considering the tool complete, manually verify:

- [ ] All six commands execute without syntax errors
- [ ] Help text displays correctly
- [ ] Default values work as expected
- [ ] Global options (-a, -e, -v) override defaults
- [ ] Version prompting works when version not specified
- [ ] Error messages are clear and helpful
- [ ] Tool validation catches missing dependencies
- [ ] Path construction works for different apps/environments
- [ ] Terraform workspace operations succeed
- [ ] kubectl commands use correct namespaces
- [ ] Port-forwarding establishes connections
- [ ] Build and deploy workflow completes successfully
