# Implementation Plan: dev.sh CLI Tool

## Overview

This implementation plan breaks down the dev.sh CLI tool into discrete, actionable coding steps. The tool will be built incrementally, starting with the script foundation, then implementing utility functions, followed by each command function, and finally wiring everything together with the main entry point and command dispatcher.

## Tasks

- [ ] 1. Set up script foundation and core structure
  - Create dev.sh file with bash shebang (#!/usr/bin/env bash)
  - Add error handling flags (set -e, set -u, set -o pipefail)
  - Define global constants (DEFAULT_APP="demo-app", DEFAULT_ENV="local")
  - Define global variables (APP, ENVIRONMENT, VERSION)
  - Implement error_exit() function that writes to stderr and exits with status 1
  - _Requirements: 10.1-10.6, 11.1, 11.2_

- [ ] 2. Implement tool validation function
  - Create validate_tools() function
  - Check for docker, terraform, kubectl, and git using command -v
  - Collect missing tools into an array
  - Call error_exit with list of missing tools if any are not found
  - _Requirements: 9.1-9.6_

- [ ] 3. Implement global argument parsing
  - Create parse_global_args() function
  - Parse -a/--app, -e/--environment, -v/--version, -h/--help flags
  - Set global variables (APP, ENVIRONMENT, VERSION) with appropriate defaults
  - Stop parsing when encountering non-global options (break from loop)
  - Handle --help by calling show_help and exiting
  - _Requirements: 8.1-8.6, 1.4, 1.5, 2.4, 2.5_

- [ ] 4. Implement core utility functions
  - [ ] 4.1 Create prompt_version() function
    - Check if VERSION global variable is empty
    - Use read command to prompt user for version name
    - Call error_exit if user provides empty input
    - _Requirements: 1.3, 2.3, 6.2, 7.2_
  
  - [ ] 4.2 Create get_infra_path() function
    - Construct path as "${APP}/infrastructure/${ENVIRONMENT}/"
    - Check if directory exists using [ -d "$path" ]
    - Call error_exit if directory doesn't exist
    - Echo the path to stdout
    - _Requirements: 12.1, 12.2_
  
  - [ ] 4.3 Create get_namespace() function
    - Construct and echo namespace as "${APP}-${VERSION}"
    - _Requirements: 13.1, 13.2_
  
  - [ ] 4.4 Create get_git_hash() function
    - Execute git rev-parse --short=8 HEAD
    - Redirect stderr to /dev/null and capture output
    - Call error_exit if git command fails
    - Echo the hash to stdout
    - _Requirements: 3.2_
  
  - [ ] 4.5 Create is_deployed() function
    - Get namespace using get_namespace()
    - Check if namespace exists using kubectl get namespace
    - Redirect output to /dev/null
    - Return 0 if namespace exists, 1 otherwise
    - _Requirements: 5.2, 13.3_
  
  - [ ] 4.6 Create get_port_forward_info() function
    - Get namespace using get_namespace()
    - Search for active kubectl port-forward process using ps aux with grep
    - Extract port mapping from command line (format: local:remote)
    - Parse local port from port mapping
    - Echo "http://localhost:<local_port>" if found, empty string otherwise
    - _Requirements: 5.3_

- [ ] 5. Implement "up" command function
  - Create cmd_up() function
  - Call prompt_version() to ensure VERSION is set
  - Get infrastructure path using get_infra_path()
  - Construct container_image variable as "${APP}:${VERSION}"
  - Display informational message about provisioning
  - Change to infrastructure directory using cd
  - Create or select terraform workspace (try select first, create if fails)
  - Run terraform apply with -var flags for environment, app_version, and container_image
  - Return to original directory using cd -
  - Display success message
  - _Requirements: 1.1, 1.2, 1.6, 12.3, 12.4, 14.1, 14.2, 14.3_

- [ ] 6. Implement "down" command function
  - Create cmd_down() function
  - Call prompt_version() to ensure VERSION is set
  - Get infrastructure path using get_infra_path()
  - Construct container_image variable as "${APP}:${VERSION}"
  - Display informational message about destroying
  - Change to infrastructure directory using cd
  - Select terraform workspace (call error_exit if workspace doesn't exist)
  - Run terraform destroy with -var flags for environment, app_version, and container_image
  - Return to original directory using cd -
  - Display success message
  - _Requirements: 2.1, 2.2, 2.6, 12.3, 12.4, 14.4_

- [ ] 7. Implement "build" command function
  - Create cmd_build() function
  - Initialize local variables for tag and deploy flag
  - Parse command-specific options (-t/--tag, -d/--deploy) using while loop
  - Default tag to git hash if not specified by calling get_git_hash()
  - Construct Dockerfile path as "${APP}/src/Dockerfile"
  - Verify Dockerfile exists using [ -f "$dockerfile" ]
  - Construct image name as "${APP}:${tag}"
  - Display informational message about building
  - Execute docker build with -t flag, -f flag for Dockerfile, and context directory
  - Display success message with image name
  - If deploy flag is true, set VERSION to tag and call cmd_up()
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1, 4.2, 4.3, 4.4_

- [ ] 8. Implement "versions" command function
  - Create cmd_versions() function
  - Get infrastructure path using get_infra_path()
  - Display header for versions list
  - Change to infrastructure directory using cd
  - Get list of terraform workspaces using terraform workspace list
  - Parse workspace list to remove markers and whitespace
  - Loop through each workspace (skip "default")
  - For each workspace, set VERSION and check deployment status using is_deployed()
  - For deployed versions, get port-forward info using get_port_forward_info()
  - Format and display output with printf showing workspace name, status, and URL
  - Return to original directory using cd -
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [ ] 9. Implement "logs" command function
  - Create cmd_logs() function
  - Initialize local variable for follow flag
  - Parse command-specific options (-f/--follow) using while loop
  - Call prompt_version() to ensure VERSION is set
  - Verify version is deployed using is_deployed() and call error_exit if not
  - Get namespace using get_namespace()
  - Display informational message about fetching logs
  - Execute kubectl logs with namespace, label selector (-l app="$APP"), and --all-containers=true
  - Add -f flag if follow is true
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [ ] 10. Implement "expose" command function
  - Create cmd_expose() function
  - Initialize local variable for port
  - Parse command-specific options (-p/--port) using while loop
  - Call error_exit if port is not provided
  - Call prompt_version() to ensure VERSION is set
  - Verify version is deployed using is_deployed() and call error_exit if not
  - Get namespace using get_namespace()
  - Display informational message with local URL
  - Execute kubectl port-forward with namespace, service name (svc/${APP}), and port mapping (${port}:80)
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

- [ ] 11. Implement help text function
  - Create show_help() function
  - Use cat with heredoc to display comprehensive usage information
  - Include sections for: usage syntax, global options, commands with their options, and examples
  - Document all flags: -a/--app, -e/--environment, -v/--version, -h/--help
  - Document all commands: up, down, build, versions, logs, expose
  - Include practical examples for common workflows
  - _Requirements: 8.4_

- [ ] 12. Implement main entry point and command dispatcher
  - Create main() function
  - Call validate_tools() first
  - Call parse_global_args() with all script arguments
  - Extract command from first positional argument after global parsing
  - Shift arguments to remove command
  - Use case statement to dispatch to appropriate cmd_* function
  - Handle "up" → cmd_up
  - Handle "down" → cmd_down
  - Handle "build" → cmd_build
  - Handle "versions" → cmd_versions
  - Handle "logs" → cmd_logs
  - Handle "expose" → cmd_expose
  - Handle "-h", "--help", "help" → show_help
  - Handle empty command → error_exit with helpful message
  - Handle unknown commands → error_exit with command name
  - Add main function invocation at end of script: main "$@"
  - _Requirements: 8.5, 10.5_

- [ ] 13. Checkpoint - Verify script completeness and test manually
  - Ensure dev.sh is executable (chmod +x dev.sh)
  - Verify all functions are defined before they are called
  - Test each command with valid inputs
  - Test error handling for missing tools
  - Test error handling for invalid commands and options
  - Test error handling for missing required arguments
  - Test error handling for non-existent resources (directories, workspaces, deployments)
  - Verify default values work correctly (demo-app, local)
  - Verify global options override defaults (-a, -e, -v)
  - Test version prompting when -v is not specified
  - Test build with default git hash tag
  - Test build with custom tag
  - Test build with --deploy flag
  - Test versions command output formatting
  - Test logs command with and without --follow
  - Test expose command with port-forwarding
  - Verify working directory is restored after terraform operations
  - Test on target platforms (Linux, macOS, Windows Git Bash/WSL)

## Notes

- All tasks involve writing or modifying the dev.sh bash script
- No automated test files will be created; testing is manual
- Each task builds incrementally on previous tasks
- Error handling is built into each function using the error_exit() utility
- All paths use forward slashes for cross-platform compatibility (Windows/Linux/macOS)
- The script uses bash best practices: set -e (exit on error), set -u (exit on undefined variable), set -o pipefail (exit on pipe failure)
- Terraform workspace operations handle both creation (new) and selection (select)
- kubectl commands use namespace (-n) and label selectors (-l) appropriately
- Global options are parsed before command-specific options
- The script maintains and restores working directory when changing to infrastructure directories
