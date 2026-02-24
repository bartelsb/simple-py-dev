# Local Development Environment

Scripts, code, and instructions to set you up for successful local dev in a Kubernetes cluster.

## Pre-requisites

Before you start, you'll need a local cluster to deploy into. The [dev.sh](dev.sh) utility script assumes that you are using [minikube](https://minikube.sigs.k8s.io/docs/start). Note that installing minikube will require installation of container software such as [Docker](https://minikube.sigs.k8s.io/docs/drivers/docker/).

## Local Application Deployment

To manage the local application deployment, use the `dev.sh` script. This script provides commands to build, deploy, and manage the application in a Kubernetes cluster. Below are some common commands:

- **Build and deploy the application**: `./dev.sh -v <version> build -d`
- **Deploy a previously built application**: `./dev.sh -v <version> up`
- **View application logs**: `./dev.sh -v <version> logs`
- **Expose the application on a local port**: `./dev.sh -v <version> expose -p <port>`
- **See the status of all deployed versions of an application**: `./dev.sh versions`
- **Tear down a deployed application**: `./dev.sh -v <version> down`

For a full list of commands and options, run `./dev.sh --help`.

### [demo-app](./demo-app/) Summary

A simple Flask web application with basic health check and version endpoints. See [application README](./demo-app/README.md) for more details.

### Folder Structure

New applications can be structured using the [demo-app](./demo-app/) application as a guide.

```
demo-app/
├── README.md
├── infrastructure/
│   ├── local/
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   └── .terraform.lock.hcl
│   └── modules/
│       └── demo-app/
│           ├── kubernetes.tf
│           └── variables.tf
└── src/
    ├── Dockerfile
    ├── requirements.txt
    └── server.py
```

- **infrastructure/local/** - Terraform configuration for local Kubernetes deployment
- **infrastructure/modules/demo-app/** - Reusable Terraform module for demo-app Kubernetes resources
- **src/** - Application source code (such as a Flask server, Docker configuration, and Python dependencies)

Additional environments can be added under the `infrastructure` directory. One or more modules containing the Kubernetes resources necessary to deploy the application can be added under the `modules` directory.

## TODO

- Add more flexible argument parsing to script. Right now, it can't handle global parameters after the command. Consider getopts.
- Expose is currently locked to service port 5000. That should be configurable.
- Expose runs in the foreground. There should be a parameter to run it in the background, and then an "unexpose" command to stop.
- The project is very opinionated (expects minikube, context called minikube, etc.). Could be made more flexible.