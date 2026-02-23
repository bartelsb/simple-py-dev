# Local Development Environment

Scripts, code, and instructions to set you up for successful local dev in a Kubernetes cluster.

## Pre-requisites

Before you start, you'll need a local cluster to deploy into. I like [minikube](https://minikube.sigs.k8s.io/docs/start). Note that installing minikube will require installation of container software such as [Docker](https://minikube.sigs.k8s.io/docs/drivers/docker/).

## [demo-app](./demo-app/)

A simple Flask web application with basic health check and version endpoints. See [application README](./demo-app/README.md) for more details.

## Local application deployment

*IMPORTANT:* Confirm that the current-context in your kubeconfig file (likely, ~/.kube/config) is set to the correct context. The [dev.sh](dev.sh) script will use the currently configured context. If you have multiple contexts configured it can be easy to deploy to the wrong cluster, so this is a step that should not be skipped.