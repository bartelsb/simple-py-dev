#!/usr/bin/env bash
set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Global constants
DEFAULT_APP="demo-app"
DEFAULT_ENV="local"

# Global variables (set by parse_global_args)
APP=""
ENVIRONMENT=""
VERSION=""

# Error handling function
error_exit() {
    echo "Error: $1" >&2
    exit 1
}
# Tool validation function
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
# Argument parsing function
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
# Prompt for version if not set
prompt_version() {
    if [ -z "$VERSION" ]; then
        read -p "Enter version name: " VERSION
        [ -z "$VERSION" ] && error_exit "Version is required"
    fi
}
# Get infrastructure path
get_infra_path() {
    local path="${APP}/infrastructure/${ENVIRONMENT}"
    [ -d "$path" ] || error_exit "Infrastructure directory not found: $path"
    echo "$path"
}

# Get Kubernetes namespace
get_namespace() {
    echo "${APP}-${VERSION}"
}

# Get git commit hash (short 8 characters)
get_git_hash() {
    git rev-parse --short=8 HEAD 2>/dev/null || error_exit "Failed to get git commit hash"
}
# Check if version is deployed
is_deployed() {
    local namespace=$(get_namespace)
    kubectl get namespace "$namespace" >/dev/null 2>&1
}

# Get port-forward info for deployed version
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
# Command: up - Provision infrastructure
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
# Command: down - Destroy infrastructure
cmd_down() {
    prompt_version
    
    local infra_path=$(get_infra_path)
    local container_image="${APP}:${VERSION}"
    
    echo "Destroying infrastructure for ${APP} version ${VERSION} in ${ENVIRONMENT}..."
    
    cd "$infra_path" || error_exit "Failed to change to infrastructure directory"
    
    # Initialize terraform
    terraform init || error_exit "Terraform init failed"

    # Select workspace (error if doesn't exist)
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
# Command: build - Build Docker image
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
# Command: versions - List all versions and their deployment status
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
# Command: logs - View logs for a version
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
# Command: expose - Set up port-forwarding to a version
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

# Display help text
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

# Main entry point and command dispatcher
main() {
    validate_tools
    
    # Parse global options and track position
    local -a all_args=("$@")
    local idx=0
    
    APP="$DEFAULT_APP"
    ENVIRONMENT="$DEFAULT_ENV"
    VERSION=""
    
    while [[ $idx -lt ${#all_args[@]} ]]; do
        case "${all_args[$idx]}" in
            -a|--app)
                APP="${all_args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
            -e|--environment)
                ENVIRONMENT="${all_args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
            -v|--version)
                VERSION="${all_args[$((idx+1))]}"
                idx=$((idx+2))
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                # Not a global option, this is the command
                break
                ;;
        esac
    done
    
    # Extract command and remaining arguments
    local command="${all_args[$idx]:-}"
    local -a cmd_args=("${all_args[@]:$((idx+1))}")
    
    case "$command" in
        up) cmd_up "${cmd_args[@]}" ;;
        down) cmd_down "${cmd_args[@]}" ;;
        build) cmd_build "${cmd_args[@]}" ;;
        versions) cmd_versions "${cmd_args[@]}" ;;
        logs) cmd_logs "${cmd_args[@]}" ;;
        expose) cmd_expose "${cmd_args[@]}" ;;
        help) show_help ;;
        "") error_exit "No command specified. Use --help for usage." ;;
        *) error_exit "Unknown command: $command" ;;
    esac
}

# Invoke main function with all arguments
main "$@"
