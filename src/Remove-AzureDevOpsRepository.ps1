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

Write-Debug "Remove-AzureDevOpsRepository.ps1: Started"
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
Write-Debug "[$($lzDirectory.BaseName)] Found $($lzFile.Name) file."

#* Parse Landing Zone configuration file
$lzConfig = Get-Content -Path $lzFile.FullName -Encoding utf8 | ConvertFrom-Json -AsHashtable -Depth 10

#* Declare Azure DevOps variables
$organization = $lzConfig.azureDevOps.organization
$project = $lzConfig.azureDevOps.projectName
$repo = $lzConfig.azureDevOps.repoName ? $lzConfig.azureDevOps.repoName : $lzConfig.repoName

#* Find existing Azure DevOps repository if any
try {
    $repoInfo = Invoke-AzureDevOpsCliCommand -Command @("repos", "show") -Organization $organization -Project $project -Parameters @{
        "repository" = $repo
    }
}
catch {
    $repoInfo = $null
}

$failedPipelineOperations = @()

if ($repoInfo) {
    Write-Host "Found Azure DevOps repository '$repo'."

    ##################################
    ###* Processing pipelines
    ##################################
    #region

    Write-Host "Processing pipelines."

    #* Process Pipelines
    if ($lzConfig.azureDevOps.pipelines) {
        foreach ($pipeline in $lzConfig.azureDevOps.pipelines) {
            $pipelineName = $pipeline.name

            ##################################
            ###* Processing pipeline
            ##################################
            #region

            Write-Host "Processing pipeline: $($pipelineName)."

            if ($pipeline.decommissioned) {
                #* Checking for existing pipelines
                try {
                    Write-Debug "Checking if pipeline should be deleted."
                    $existingPipeline = Invoke-AzureDevOpsCliCommand -Command @("pipelines", "show") -Organization $organization -Project $project -Parameters @{
                        "name" = $pipelineName
                    }

                    if ($existingPipeline) {
                        #* Deleting pipeline
                        try {
                            Invoke-AzureDevOpsCliCommand -Command @("pipelines", "delete") -Organization $organization -Project $project -Parameters @{
                                "id" = $existingPipeline.id
                                "yes" = $null
                            }
                            Write-Host "[$pipelineName] Successfully deleted Azure DevOps pipeline."
                        }
                        catch {
                            $failedPipelineOperations += $pipelineName
                            Write-Error "[$pipelineName] Failed to delete Azure DevOps pipeline. Error: $($_.Exception.Message)"
                        }
                    }
                    else {
                        Write-Host "[$pipelineName] Skipped. Azure DevOps pipeline already deleted or not found."
                    }
                }
                catch {
                    $failedPipelineOperations += $pipelineName
                    Write-Error "[$pipelineName] Failed to check Azure DevOps pipeline status. Error: $($_.Exception.Message)"
                }
            }
            else {
                Write-Debug "Skipped. Pipeline not set to decommissioned in $($lzFile.Name) file."
            }

            #endregion
        }
    }
    
    #endregion

    ##################################
    ###* Disable/Remove repository
    ##################################
    #region

    Write-Debug "Checking if repository should be disabled or removed."

    if ($lzConfig.decommissioned) {
        try {
            # Azure DevOps doesn't have an "archive" concept like GitHub
            # Instead, we can disable the repository or delete it entirely
            # For safety, we'll disable rather than delete
            Write-Host "- Disabling repository (Azure DevOps equivalent of archiving)"
            
            # Note: Disabling a repository in Azure DevOps requires REST API calls
            # The CLI doesn't have a direct disable command
            Write-Warning "Repository disabling requires REST API implementation. Repository will remain active."
            
            # Alternative: Delete the repository entirely (more destructive)
            # Uncomment the following lines if deletion is preferred over disabling
            # Write-Host "- Deleting repository"
            # Invoke-AzureDevOpsCliCommand -Command @("repos", "delete") -Organization $organization -Project $project -Parameters @{
            #     "id" = $repoInfo.id
            #     "yes" = $null
            # }
            # Write-Host "Successfully deleted repository."
        }
        catch {
            throw "Failed to disable/remove Azure DevOps repository. Error: $($_.Exception.Message)"
        }
    }
    else {
        Write-Debug "Skipped. Repository not set to decommissioned in $($lzFile.Name) file."
    }
    
    #endregion
}
else {
    Write-Debug "Skipped. Repository not found."
}

#* Report failed operations
if ($failedPipelineOperations.Count -gt 0) {
    Write-Warning "Failed to process the following pipelines: $($failedPipelineOperations -join ', ')"
}

#endregion