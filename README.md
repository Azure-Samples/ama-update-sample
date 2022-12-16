# Azure Managed Application Updating Sample

## Description

This sample demonstrates how to create an Azure Managed Application with a link to a publisher's backend to be able to receive commands to update the managed application using docker containers with IaC code running in the context of the Managed Resource Group.

## Prerequisites

- Azure Subscription
- Azure CLI
- Docker
- Appliance Resource Provider Object Id (it can be retrieve searching for "Appliance Resource Provider in the Azure Portal, in the Active Directory section)

## Repository Structure

```bash
ama-update-sample
├── .devcontainer               # devcontainer configuration
├── .vscode                     # vscode configuration
├── ama                         # Azure Managed Application components
│   └── commands                # "commands" function to be deployed in the Managed Resource Group    
│   ├── definition              # Azure Managed Application definition (bicep + json templates)
│   └── resources               # Docker image with IaC code to be deployed in the Managed Resource Group
├── publisher                   # Publisher's backend components
│   ├── deployment              # "deployment" function to be deployed in the publisher's backend
│   ├── events                  # "events" function to be deployed in the publisher's backend
│   ├── setcomandurl            # "setcommandurl" function to be deployed in the publisher's backend
│   ├── webhook                 # "webhook" function to be deployed in the publisher's backend
│   └── iac                     # IaC code to deploy the publisher's backend
└── utils                       # Utility classes used by all the functions
```

## Deploying the publisher's backend an the Azure Managed Application definition

To deploy the publisher's backend and the Azure Managed Application definition, you need to run the following commands in the root folder of the repository:

```bash
export RESOURCE_GROUP_NAME=<resource group name>
export LOCATION=<location>
export APPLIANCE_RESOURCE_PROVIDER_OBJECT_ID=<object id>

./deploy.sh
```

This will create a resource group with the name specified in the RESOURCE_GROUP_NAME environment variable, and deploy all the resources in that resource group. It will also create an Azure Managed Application definition called `ama-update-sample` in the service catalog.

## Deploying the Azure Managed Application

Instances of the Azure Managed Application can be created using the `az` CLI or the Azure Portal.

During the deployment, the publisher's backend will be notified of the deployment, and the `webhook` function will be triggered. This function will create an entry in the deployed Cosmos DB database containing the deployment `applicationId`.

The last phase of the deployment will invoke the `setcommandurl` function, which will update the `commandUrl` property of the Cosmos DB record with the URL and key of the `commands` function deployed in the Managed Resource Group.

## Updating an Azure Managed Application instance

To update an Azure Managed Application instance, you can send a POST request to the `deployment` function deployed in the publisher's backend. The body of the request should be a json with the `applicationId` of the Azure Managed Application instance to be updated, and the full name of the docker image to deploy in the `image` field. During the backend deployment phase, a sample image was deployed in the publisher's backend, so you can use that image for the update. The image is `<prefix>acr.azurecr.io/ama-update-sample-resources:<tag>` and can be found in the publisher's Container Registry.

When a new deployment is triggered in the Managed Resource Group, the `events` function will be triggered. This function will add a new entry in the Cosmos DB database with the `applicationId` and the `image` of the deployment.

```bash

## Cleaning up the publisher's backend

To delete all the deployed resources, you can run the following command:

```bash
# by default, it will pick up the resource group name used in the deployment
# To override it, you can export the RESOURCE_GROUP_NAME environment variable
./cleanup.sh
```
