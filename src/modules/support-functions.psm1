function Invoke-GitHubCliApiMethod {
    [CmdletBinding()]
    param (
        [string]
        $Uri,

        [string]
        $Method,

        [string]
        $Body
    )
    
    if ($Method -eq "GET") {
        $response = gh api $Uri `
            --method $Method `
            --header "Accept: application/vnd.github+json" `
            --header "X-GitHub-Api-Version: 2022-11-28" `
            --paginate `
            --slurp
    }
    else {
        $response = $Body | gh api $Uri `
            --method $Method `
            --header "Accept: application/vnd.github+json" `
            --header "X-GitHub-Api-Version: 2022-11-28" `
            --input -
    }
    
    if ($?) {
        return ($response | ConvertFrom-Json)
    }
    else {
        throw ($response | ConvertFrom-Json)
    }
}

function Join-HashTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [hashtable]
        $Hashtable1 = @{},
        
        [Parameter(Mandatory = $false)]
        [hashtable]
        $Hashtable2 = @{}
    )

    #* Null handling
    $Hashtable1 = $Hashtable1.Keys.Count -eq 0 ? @{} : $Hashtable1
    $Hashtable2 = $Hashtable2.Keys.Count -eq 0 ? @{} : $Hashtable2

    #* Needed for nested enumeration
    $hashtable1Clone = $Hashtable1.Clone()
    
    foreach ($key in $hashtable1Clone.Keys) {
        if ($key -in $hashtable2.Keys) {
            if ($hashtable1Clone[$key] -is [hashtable] -and $hashtable2[$key] -is [hashtable]) {
                $Hashtable2[$key] = Join-HashTable -Hashtable1 $hashtable1Clone[$key] -Hashtable2 $Hashtable2[$key]
            }
            elseif ($hashtable1Clone[$key] -is [array] -and $hashtable2[$key] -is [array]) {
                foreach ($item in $hashtable1Clone[$key]) {
                    if ($hashtable2[$key] -notcontains $item) {
                        $hashtable2[$key] += $item
                    }
                }
            }
        }
        else {
            $Hashtable2[$key] = $hashtable1Clone[$key]
        }
    }
    
    return $Hashtable2
}

function Join-Arrays {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [array]
        $Array1 = @(),
        
        [Parameter(Mandatory = $false)]
        [array]
        $Array2 = @()
    )

    foreach ($item in $Array1) {
        if ($Array2 -notcontains $item) {
            $Array2 += $item
        }
    }

    $Array2
}

function Invoke-AzureDevOpsCliApiMethod {
    [CmdletBinding()]
    param (
        [string]
        $Uri,

        [string]
        $Method,

        [string]
        $Body,

        [string]
        $Organization,

        [string]
        $Project
    )
    
    $args = @()
    $args += "devops"
    $args += "invoke"
    $args += "--area"
    $args += ($Uri -split '/')[1]
    $args += "--resource"
    $args += ($Uri -split '/')[2]
    
    if ($Organization) {
        $args += "--organization"
        $args += $Organization
    }
    
    if ($Project) {
        $args += "--project"
        $args += $Project
    }
    
    $args += "--http-method"
    $args += $Method
    
    if ($Body -and $Method -ne "GET") {
        $args += "--in-file"
        $args += "-"
    }
    
    try {
        if ($Body -and $Method -ne "GET") {
            $response = $Body | & az @args
        }
        else {
            $response = & az @args
        }
        
        if ($LASTEXITCODE -eq 0) {
            return ($response | ConvertFrom-Json)
        }
        else {
            throw "Azure DevOps CLI command failed with exit code $LASTEXITCODE"
        }
    }
    catch {
        throw "Failed to execute Azure DevOps CLI command: $($_.Exception.Message)"
    }
}

function Invoke-AzureDevOpsCliCommand {
    [CmdletBinding()]
    param (
        [string[]]
        $Command,

        [string]
        $Organization,

        [string]
        $Project,

        [hashtable]
        $Parameters = @{}
    )
    
    $args = @("devops") + $Command
    
    if ($Organization) {
        $args += "--organization"
        $args += $Organization
    }
    
    if ($Project) {
        $args += "--project"
        $args += $Project
    }
    
    foreach ($key in $Parameters.Keys) {
        $args += "--$key"
        if ($Parameters[$key] -ne $null -and $Parameters[$key] -ne "") {
            $args += $Parameters[$key]
        }
    }
    
    try {
        $response = & az @args
        
        if ($LASTEXITCODE -eq 0) {
            if ($response) {
                try {
                    return ($response | ConvertFrom-Json)
                }
                catch {
                    # If conversion fails, return raw response
                    return $response
                }
            }
            return $null
        }
        else {
            throw "Azure DevOps CLI command failed with exit code $LASTEXITCODE. Response: $response"
        }
    }
    catch {
        throw "Failed to execute Azure DevOps CLI command: $($_.Exception.Message)"
    }
}
