# Azure DevOps Integration for Climpr Landing Zones

This document describes how to use the Azure DevOps integration capabilities of the Climpr Landing Zone solution.

## Overview

The Azure DevOps integration provides unified tooling for managing repositories and pipelines alongside the existing GitHub functionality. This enables teams to use either platform while maintaining consistent automation and configuration patterns.

## Prerequisites

1. **Azure DevOps CLI Extension**: The Azure CLI with the DevOps extension must be installed and configured.
   ```bash
   az extension add --name azure-devops
   ```

2. **Authentication**: You must be authenticated with Azure DevOps either through:
   - Personal Access Token (PAT)
   - Azure AD authentication
   - Service Principal

3. **Permissions**: The authenticated user/service principal must have appropriate permissions in the Azure DevOps organization and project.

## Configuration

### Landing Zone metadata.json

Add Azure DevOps configuration to your Landing Zone `metadata.json` file:

```json
{
  "organization": "your-github-org",
  "repoName": "my-landing-zone",
  "azureDevOps": {
    "organization": "https://dev.azure.com/your-org",
    "projectName": "your-project",
    "repoName": "my-landing-zone-ado",
    "defaultBranch": "main",
    "access": {
      "teams": {
        "contributor": ["team1", "team2"],
        "reader": ["team3"]
      },
      "users": {
        "admin": ["user1@domain.com"],
        "contributor": ["user2@domain.com"]
      }
    },
    "branchPolicies": {
      "requireReviewers": true,
      "minimumReviewers": 2,
      "requireBuildValidation": true
    },
    "pipelines": [
      {
        "name": "CI/CD Pipeline",
        "yamlPath": "azure-pipelines.yml",
        "decommissioned": false
      }
    ],
    "buildValidation": [
      {
        "name": "Build Validation",
        "pipelineId": "build-pipeline-id",
        "path": "/"
      }
    ]
  },
  "decommissioned": false
}
```

### climprconfig.json

Configure default Azure DevOps settings in your `climprconfig.json`:

```json
{
  "lzManagement": {
    "azureDevOpsWorkloadRepository": {
      "access": {
        "teams": {
          "contributor": [],
          "reader": []
        },
        "users": {
          "admin": [],
          "contributor": []
        }
      },
      "branchPolicies": {
        "requireReviewers": true,
        "minimumReviewers": 1,
        "requireBuildValidation": false
      }
    }
  }
}
```

## Usage

### Creating a Repository and Pipelines

1. **Configure your Landing Zone**: Update the `metadata.json` file with Azure DevOps settings.

2. **Run the deployment**: The Azure DevOps scripts will be automatically executed as part of the Landing Zone deployment process.

3. **Manual execution**: You can also run the scripts manually:
   ```powershell
   .\Deploy-AzureDevOpsRepository.ps1 -LandingZonePath "path/to/landing-zone" -SolutionPath "path/to/solution"
   ```

### Decommissioning

1. **Mark as decommissioned**: Set `"decommissioned": true` in your `metadata.json`.

2. **Run removal**: The removal scripts will be executed automatically or manually:
   ```powershell
   .\Remove-AzureDevOpsRepository.ps1 -LandingZonePath "path/to/landing-zone" -SolutionPath "path/to/solution"
   ```

## Common Workflows

### Repository Creation
- Creates a new Git repository in the specified Azure DevOps project
- Configures default branch settings
- Sets up team and user permissions
- Applies branch policies for code quality

### Pipeline Setup
- Creates build and release pipelines from YAML definitions
- Configures pipeline permissions and security
- Sets up build validation policies
- Links pipelines to repository branches

### Permissions Management
- Manages team-based access control
- Configures individual user permissions
- Supports role-based security models
- Integrates with Azure AD for identity management

### Branch Protection
- Enforces code review requirements
- Mandates build validation before merge
- Configures path-based policies
- Sets up automated compliance checks

## Azure DevOps CLI Commands Used

The scripts leverage the following Azure DevOps CLI commands:

### Repository Management
```bash
az repos create --name "repo-name" --project "project-name"
az repos show --repository "repo-name" --project "project-name"
az repos delete --id "repo-id" --project "project-name" --yes
```

### Pipeline Management
```bash
az pipelines create --name "pipeline-name" --repository "repo-name" --branch "main" --yaml-path "azure-pipelines.yml"
az pipelines show --name "pipeline-name" --project "project-name"
az pipelines delete --id "pipeline-id" --project "project-name" --yes
```

### Security and Permissions
```bash
az devops security permission update --namespace-id "namespace-id" --subject "subject" --token "token" --allow-bit "permission-bit"
```

## Limitations and Considerations

1. **Repository Templates**: Azure DevOps doesn't support repository templates like GitHub. Consider using repository import or manual setup for template-like functionality.

2. **Branch Policies**: Advanced branch policies require REST API calls beyond the CLI capabilities. Some features may need additional implementation.

3. **Permissions**: Granular permissions management in Azure DevOps is complex and may require additional REST API integration.

4. **Archiving**: Azure DevOps doesn't have a direct equivalent to GitHub's repository archiving. The scripts disable repositories instead.

## Troubleshooting

### Authentication Issues
```bash
az devops configure --defaults organization=https://dev.azure.com/your-org project=your-project
az login
```

### Permission Errors
Ensure your user/service principal has:
- Project Collection Administrator rights (for organization-level operations)
- Project Administrator rights (for project-level operations)
- Repository Administrator rights (for repository operations)

### CLI Extension Issues
```bash
az extension update --name azure-devops
az extension show --name azure-devops
```

## Examples

See the `examples/` directory for complete configuration examples and sample workflows.