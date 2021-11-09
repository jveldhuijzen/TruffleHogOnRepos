<#
.SYNOPSIS
    Automate the truffleHog process through an entire set of git repos.
.EXAMPLE
    PS> TruffleHogOnRepos --path C:\path\to\my\repos    
.DESCRIPTION
    This script will run through an entire GitHub Company's set of repositories, clone it to disk and then scan it (multi threaded) with truffleHog.
    When it has findings it will create a json file per repo detailing it's findings.
.PARAMETER CompanyName
    The name of the company you want to scan
.PARAMETER path
    The path of the repo(s) you want to scan
.PARAMETER outputPath
    The path where the output will be dropped
#>

param (
    [string]$CompanyName,
    [string]$path,
    [string]$outputPath
)

if (!$path) {
    $path = Get-Location;
    Write-host $path
}
if (!$outputPath) {
    $outputPath = "$path\truffleHogOutput"
}
$outputPathExists = Test-Path $outputPath
if (!$outputPathExists) {
    New-Item -Path $outputPath -ItemType Directory
}

function Split-Array() {
    param([array]$arrayToSplit, [int]$chunkSize)
    
    # Defining the chunk size
    if ($chunkSize -le 0) {
        $chunkSize = 6
    }

    $chunkedArray = @()
    $parts = [math]::Ceiling($arrayToSplit.Length / $chunkSize)
  
    # Splitting the array to chunks of the same size
    for ($i = 0; $i -le $parts; $i++) {
        $start = $i * $chunkSize
        $end = (($i + 1) * $chunkSize) - 1
        $chunkedArray += , @($arrayToSplit[$start..$end])
    }

    return $chunkedArray
}

function GetAllReposFromCompany() {
    param ([string]$CompanyName)
    $companyUrl = "https://api.github.com/orgs/$CompanyName/repos?per_page=1000"

    if (!$CompanyName) {
        Write-Error "Both Company name and User name are null or empty."
        throw;
    }
            
    try {
        $result = Invoke-WebRequest -Method GET -Uri $companyUrl -ErrorAction Stop
        
        # This will only execute if the Invoke-WebRequest is successful.
        $statusCode = $Response.StatusCode
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusMessage = $_.Exception.Response.StatusMessage.value__
        Write-Error "Couldn't read GitHub API. Api returned code $statusCode"
        $statusMessage
    }

    try {
        $repos = $result.Content | ConvertFrom-Json
    }
    catch {
        Write-Error "Couldn't read JSON returned by GitHub API"
    }

    return $repos;
}

function CloneRepos {
    param ($repos)

    $count = $repos.Count
    Write-Output "Starting cloning $count repositories"
    $outArray = Split-Array $repos 6

    foreach ($repo in $outArray) {
        # run the jobs to clone the array
        CloneRepoJob $repo
    }

}

function CloneRepoJob {
    param ($repos)
    $scriptBlock = {
        param($repo, $path) 
        $repoName = $repo.name
        Write-Output "Getting repo: $repoName"
        $url = $repo.clone_url

        git clone $url "$path\$repoName"
    }

    $repos | ForEach-Object {
        # pass the loop variable across the job-context barrier
        Start-Job $scriptBlock -ArgumentList $_, $path -Name "git-clone"
    }

    # Wait for all to complete
    While (Get-Job -State "Running") { Start-Sleep 2 }
}

function RunTruffleHogJob {
    param ([array]$folders)

    $scriptBlock = {
        param($dir, $path, $outputPath) 
        $dirName = $dir.Name;
        
        Write-Output "Running TruffleHog on: $dirName"
        $fullPath = "$path\$dirname";
        try {
            trufflehog --json $fullPath > "$outputPath\$dirName.json" 2> "$outputPath\error.log"
        }
        catch {
            $_
        }
    } 

    $folders | ForEach-Object {
        # pass the loop variable across the job-context barrier
        Start-Job $scriptBlock -ArgumentList $_, $path, $outputPath -Name "TH_$_"
    }
    # Wait for all to complete
    While (Get-Job -State "Running") { Start-Sleep 2 }
}

function RunTruffleHog() {
    $folders = Get-ChildItem $path -Directory
    $count = $folders.Count
    Write-Output "Running trufflehog on $count folders"

    $arraysOfDirectories = Split-Array $folders 6

    foreach ($dirs in $arraysOfDirectories) {
        # run the jobs to let trufflehog scan the repo
        RunTruffleHogJob $dirs
    }

    $createdFiles = Get-ChildItem $outputPath -File -Filter *.json
    $emptyFiles = $createdFiles | Where-Object Length -lt 1Kb 
    $nonEmptyFiles = $createdFiles | Where-Object Length -gt 0Kb

    foreach ($emptyFile in $emptyFiles) {
        Remove-Item $emptyFile.FullName
    }
    
    Write-Host "Created output in the files below:" -ForegroundColor Yellow

    # Output the result files on the screen
    Write-Host "Output path: $outputPath" -ForegroundColor Gray
    $nonEmptyFiles
}
$banner = @"
_______                ___   ___  __         _______                   
|_     _|.----..--.--..'  _|.'  _||  |.-----.|   |   |.-----..-----.    
  |   |  |   _||  |  ||   _||   _||  ||  -__||       ||  _  ||  _  |    
  |___|  |__|  |_____||__|  |__|  |__||_____||___|___||_____||___  |    
                                                             |_____|    
                    _______                                        
                    |       |.-----.                                
                    |   -   ||     |                                
                    |_______||__|__|                                
                                                                        
             ______                                                     
            |   __ \.-----..-----..-----..-----.                        
            |      <|  -__||  _  ||  _  ||__ --|                        
            |___|__||_____||   __||_____||_____|                        
                           |__|                                         
"@
Write-Host $banner -ForegroundColor Yellow

$cloneUrls = GetAllReposFromCompany $CompanyName $UserName
CloneRepos $cloneUrls
RunTruffleHog

Write-Host "`n`n`nAll done :)"