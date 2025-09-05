#Requires -Modules @{ ModuleName="Az.Accounts"; ModuleVersion="3.0.4" }

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateScript({ $_ | Test-Path -PathType Container })]
    [string]
    $LandingZonePath,

    [Parameter(Mandatory)]
    [ValidateScript({ $_ | Test-Path -PathType Container })]
    [string]
    $SolutionPath
)

Write-Debug "Deploy-AzureDevOpsRepository.ps1: Started"
Write-Debug "Input parameters: $($PSBoundParameters | ConvertTo-Json -Depth 3)"

#* Establish defaults
$scriptRoot = $PSScriptRoot
Write-Debug "Working directory: $((Resolve-Path -Path .).Path)"
Write-Debug "Script root directory: $(Resolve-Path -Relative -Path $scriptRoot)"

#* Import Modules
Import-Module $scriptRoot/modules/support-functions.psm1 -Force

#* Resolve files
$lzFile = Get-Item -Path "$LandingZonePath/metadata.json" -Force
$lzDirectory = Get-Item -Path $LandingZonePath -Force
Write-Debug "[$($lzDirectory.BaseName)] Found ($lzFile.Name) file."

#* Parse climprconfig.json
$climprConfigPath = (Test-Path -Path "$SolutionPath/climprconfig.json") ? "$SolutionPath/climprconfig.json" : "climprconfig.json"
$climprConfig = Get-Content -Path $climprConfigPath | ConvertFrom-Json -AsHashtable -Depth 10 -NoEnumerate

#* Declare climprconfig settings
$defaultRepositoryConfig = $climprConfig.lzManagement.azureDevOpsWorkloadRepository

#* Parse Landing Zone configuration file
$lzConfig = Get-Content -Path $lzFile.FullName -Encoding utf8 | ConvertFrom-Json -AsHashtable -Depth 10

#* Declare Azure DevOps variables
$organization = $lzConfig.azureDevOps.organization
$project = $lzConfig.azureDevOps.projectName
$repo = $lzConfig.azureDevOps.repoName ? $lzConfig.azureDevOps.repoName : $lzConfig.repoName
$defaultBranch = $lzConfig.azureDevOps.defaultBranch ? $lzConfig.azureDevOps.defaultBranch : "main"

#* MARK: Configure Azure DevOps repository
Write-Host "Configure Azure DevOps repository"

if (!$lzConfig.decommissioned) {
    ##################################
    ###* Configure Azure DevOps repository
    ##################################
    #region

    #* Check if the repository already exists
    Write-Host "- Check if the repository already exists '$repo'"
    try {
        $repoInfo = Invoke-AzureDevOpsCliCommand -Command @("repos", "show") -Organization $organization -Project $project -Parameters @{
            "repository" = $repo
        }
        if ($repoInfo) {
            Write-Host "- Found Azure DevOps repository '$repo'"
        }
    }
    catch {
        $repoInfo = $null
        Write-Host "- Repository '$repo' not found, will create it"
    }

    if (!$repoInfo) {
        Write-Host "- Creating repository [$repo]"
        try {
            $createParams = @{
                "name" = $repo
                "project" = $project
            }
            
            if ($lzConfig.azureDevOps.repoTemplate) {
                # Note: Azure DevOps doesn't have direct template support like GitHub
                # This would need to be implemented via repository import or manual setup
                Write-Warning "Repository templates are not directly supported in Azure DevOps CLI. Creating blank repository."
            }

            $repoInfo = Invoke-AzureDevOpsCliCommand -Command @("repos", "create") -Organization $organization -Parameters $createParams
            Write-Host "- Created repository [$repo]"
        }
        catch {
            Write-Error "Failed to create repository [$repo]. Error: $($_.Exception.Message)"
        }
    }

    #endregion

    ##################################
    ###* MARK: Configure default branch
    ##################################
    #region
    Write-Host "Configure default branch"

    if ($repoInfo -and $defaultBranch -ne "main") {
        try {
            # Set the default branch (this may require the branch to exist first)
            Write-Host "- Setting default branch to [$defaultBranch]"
            # Note: Azure DevOps CLI doesn't have a direct command to set default branch
            # This would typically be done via REST API or portal
            Write-Warning "Setting default branch via CLI is not directly supported. Please configure via Azure DevOps portal."
        }
        catch {
            Write-Error "Failed to set default branch. Error: $($_.Exception.Message)"
        }
    }

    #endregion

    ##################################
    ###* MARK: Configure repository permissions
    ##################################
    #region
    Write-Host "Configure repository permissions"

    if ($defaultRepositoryConfig.access) {
        #* Merge desired default permissions and lzconfig permissions
        $accessList = Join-HashTable -Hashtable1 $defaultRepositoryConfig.access -Hashtable2 $lzConfig.azureDevOps.access

        Write-Host "- Desired access table"
        Write-Host ($accessList | ConvertTo-Json -Depth 2)

        #* Configure team permissions
        if ($accessList.teams) {
            foreach ($permission in $accessList.teams.Keys) {
                foreach ($teamName in $accessList.teams[$permission]) {
                    try {
                        Write-Host "- Assigning [$permission] permission for team [$teamName] on repository [$repo]"
                        # Note: Azure DevOps security permissions are complex and typically require REST API calls
                        # The CLI has limited support for granular permissions
                        Write-Warning "Team permissions assignment via CLI requires additional implementation"
                    }
                    catch {
                        Write-Error "Failed to assign permission for team [$teamName]. Error: $($_.Exception.Message)"
                    }
                }
            }
        }

        #* Configure user permissions
        if ($accessList.users) {
            foreach ($permission in $accessList.users.Keys) {
                foreach ($userName in $accessList.users[$permission]) {
                    try {
                        Write-Host "- Assigning [$permission] permission for user [$userName] on repository [$repo]"
                        # Note: User permissions also require REST API or specific security commands
                        Write-Warning "User permissions assignment via CLI requires additional implementation"
                    }
                    catch {
                        Write-Error "Failed to assign permission for user [$userName]. Error: $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    #endregion

    ##################################
    ###* MARK: Set repository policies
    ##################################
    #region
    Write-Host "Set repository policies"

    #* Determine configuration source
    $config = $null
    if ($null -ne $lzConfig.azureDevOps.branchPolicies) {
        Write-Host "- Branch policies determined by Landing Zone configuration file."
        $config = $lzConfig.azureDevOps.branchPolicies
    }
    elseif ($null -ne $defaultRepositoryConfig.branchPolicies) {
        Write-Host "- Branch policies determined by climprconfig file."
        $config = $defaultRepositoryConfig.branchPolicies
    }
    else {
        Write-Host "- Skipping. Branch policies unset in both Landing Zone and climprconfig files."
    }

    #* Configure policies
    if ("ignore" -eq $config) {
        Write-Host "- Skipping. Branch policies set to 'ignore'."
    }
    elseif ("default" -eq $config) {
        Write-Host "- Branch policies set to 'default'. No specific policies will be applied."
    }
    elseif ($null -ne $config) {
        Write-Host "- Branch policies configuration: $($config | ConvertTo-Json -Depth 10)"
        try {
            # Branch policies in Azure DevOps are complex and require specific REST API calls
            # The CLI has limited support for policy management
            Write-Warning "Branch policies configuration via CLI requires additional REST API implementation"
        }
        catch {
            Write-Error "Failed to configure branch policies. Error: $($_.Exception.Message)"
        }
    }

    #endregion

    ##################################
    ###* MARK: Create pipelines
    ##################################
    #region
    Write-Host "Create pipelines"

    if ($lzConfig.azureDevOps.pipelines) {
        foreach ($pipeline in $lzConfig.azureDevOps.pipelines) {
            $pipelineName = $pipeline.name
            $pipelineYamlPath = $pipeline.yamlPath

            if ($pipeline.decommissioned) {
                Write-Host "[$pipelineName] Skipping. Pipeline decommissioned."
                continue
            }

            #* Check if pipeline exists
            try {
                $existingPipeline = Invoke-AzureDevOpsCliCommand -Command @("pipelines", "show") -Organization $organization -Project $project -Parameters @{
                    "name" = $pipelineName
                }
                
                if ($existingPipeline) {
                    Write-Host "- Pipeline [$pipelineName] already exists"
                } else {
                    Write-Host "- Creating pipeline [$pipelineName]"
                    $createPipelineParams = @{
                        "name" = $pipelineName
                        "repository" = $repo
                        "branch" = $defaultBranch
                        "yaml-path" = $pipelineYamlPath
                        "repository-type" = "tfsgit"
                    }

                    $newPipeline = Invoke-AzureDevOpsCliCommand -Command @("pipelines", "create") -Organization $organization -Project $project -Parameters $createPipelineParams
                    Write-Host "- Created pipeline [$pipelineName]"
                }
            }
            catch {
                Write-Error "Failed to process pipeline [$pipelineName]. Error: $($_.Exception.Message)"
            }
        }
    }

    #endregion

    ##################################
    ###* MARK: Configure build validation
    ##################################
    #region
    Write-Host "Configure build validation"

    if ($lzConfig.azureDevOps.buildValidation) {
        foreach ($validation in $lzConfig.azureDevOps.buildValidation) {
            try {
                Write-Host "- Configuring build validation: $($validation.name)"
                # Build validation policies require REST API calls
                Write-Warning "Build validation policies configuration via CLI requires additional implementation"
            }
            catch {
                Write-Error "Failed to configure build validation. Error: $($_.Exception.Message)"
            }
        }
    }

    #endregion
}
else {
    Write-Host "- Skipping. Landing Zone is decommissioned."
}