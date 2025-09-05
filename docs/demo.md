# Azure DevOps Integration Demo

This demo shows how to use the new Azure DevOps integration features.

## Quick Start Demo

### 1. Create a sample Landing Zone configuration

```json
{
  "organization": "my-github-org",
  "repoName": "sample-landing-zone",
  "azureDevOps": {
    "organization": "https://dev.azure.com/my-org",
    "projectName": "landing-zones",
    "repoName": "sample-lz-ado",
    "pipelines": [
      {
        "name": "Deploy Pipeline",
        "yamlPath": "azure-pipelines.yml",
        "decommissioned": false
      }
    ]
  },
  "decommissioned": false
}
```

### 2. Use in GitHub Actions workflow

```yaml
- name: Deploy Landing Zone with Azure DevOps support
  uses: devoteamcloudify/deploy-landing-zone-fork@v1
  with:
    solution-path: ./lz-management
    landing-zone-path: ./lz-management/landing-zones/my-lz
    # ... other parameters
```

### 3. Azure DevOps CLI Commands Generated

The scripts will execute commands like:
- `az repos create --name "sample-lz-ado" --project "landing-zones"`
- `az pipelines create --name "Deploy Pipeline" --yaml-path "azure-pipelines.yml"`

### 4. Manual Script Execution

```powershell
# Deploy Azure DevOps repository and pipelines
.\Deploy-AzureDevOpsRepository.ps1 -LandingZonePath "./landing-zone" -SolutionPath "./solution"

# Remove Azure DevOps repository and pipelines
.\Remove-AzureDevOpsRepository.ps1 -LandingZonePath "./landing-zone" -SolutionPath "./solution"
```

## Features Demonstrated

✅ **Repository Management**: Create and configure Azure DevOps repositories
✅ **Pipeline Automation**: Set up CI/CD pipelines from YAML definitions  
✅ **Permissions Control**: Configure team and user access
✅ **Branch Policies**: Enforce code review requirements
✅ **Unified Configuration**: Same metadata.json for GitHub and Azure DevOps
✅ **Error Handling**: Robust error handling and logging
✅ **CLI Integration**: Extensive use of Azure DevOps CLI commands

## Next Steps

1. Configure Azure DevOps CLI authentication
2. Add Azure DevOps settings to your Landing Zone metadata.json
3. Run the deployment to see Azure DevOps integration in action!