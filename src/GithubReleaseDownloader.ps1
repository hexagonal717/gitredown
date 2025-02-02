<#
.SYNOPSIS
    Reads 'repos.json' in the same folder (src) 
    and downloads the selected assets from GitHub releases.
#>

# The folder containing this script, e.g. C:\SomeProject\src
$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path

# One level above $scriptFolder (e.g. C:\SomeProject)
$parentFolder = Split-Path $scriptFolder -Parent

# A 'downloads' folder one level above (e.g. C:\SomeProject\downloads)
$downloadsFolder = Join-Path $parentFolder "downloads"

# repos.json in the script folder (src)
$jsonFile = Join-Path $scriptFolder "repos.json"

# Create the downloads folder if it doesn't exist
if (-not (Test-Path $downloadsFolder)) {
    New-Item -ItemType Directory -Path $downloadsFolder | Out-Null
}

if (-not (Test-Path $jsonFile)) {
    Write-Host "JSON file not found at: $jsonFile"
    Read-Host "Press Enter to exit..."
    return
}

try {
    $repoList = Get-Content -Path $jsonFile -Raw | ConvertFrom-Json
    $repoList = @($repoList) # Force $repoList into an array
}
catch {
    Write-Host "Failed to parse $jsonFile. Error: $($_.Exception.Message)"
    Read-Host "Press Enter to exit..."
    return
}

if (-not $repoList -or $repoList.Count -eq 0) {
    Write-Host "No valid repositories found in $jsonFile."
    Read-Host "Press Enter to exit..."
    return
}

Write-Host "Found $($repoList.Count) repositories."
for ($i = 0; $i -lt $repoList.Count; $i++) {
    Write-Host "$($i + 1). $($repoList[$i].Owner)/$($repoList[$i].Name)"
}

$repoSelection = Read-Host "`nEnter repo numbers to process (comma-separated) or type 'all'"

if ($repoSelection -eq 'all') {
    $selectedRepos = $repoList
} else {
    $indices = ($repoSelection -split ',') `
        | ForEach-Object { $_.Trim() } `
        | Where-Object { $_ -match '^\d+$' } `
        | ForEach-Object { [int]$_ - 1 } `
        | Where-Object { $_ -ge 0 -and $_ -lt $repoList.Count }

    if ($indices.Count -eq 0) {
        Write-Host "No valid repository selections."
        Read-Host "Press Enter to exit..."
        return
    }

    $selectedRepos = foreach ($idx in $indices) { $repoList[$idx] }
}

# Collect asset choices for all selected repositories
$downloadQueue = @()
foreach ($repo in $selectedRepos) {
    $owner = $repo.Owner.Trim()
    $repoName = $repo.Name.Trim()

    $apiUrl = "https://api.github.com/repos/$($owner)/$($repoName)/releases/latest"
    Write-Host "`nFetching latest release from $apiUrl..."

    try {
        $releaseData = Invoke-RestMethod -Uri $apiUrl -Headers @{
            "User-Agent" = "PowerShellScript"
            "Accept"     = "application/vnd.github.v3+json"
        } -ErrorAction Stop

        Write-Host "Latest release for $($owner)/$($repoName): $($releaseData.tag_name)"

        if ($releaseData.assets.Count -eq 0) {
            Write-Host "No assets found for $($owner)/$($repoName)."
            continue
        }

        Write-Host "`nAvailable assets:"
        for ($i = 0; $i -lt $releaseData.assets.Count; $i++) {
            Write-Host "$($i + 1). $($releaseData.assets[$i].name)"
        }

        $assetSelection = Read-Host "Enter asset numbers to download (comma-separated), or 'all'"

        $selectedAssets = if ($assetSelection -eq 'all') {
            $releaseData.assets
        } else {
            $aIndices = ($assetSelection -split ',') `
                | ForEach-Object { $_.Trim() } `
                | Where-Object { $_ -match '^\d+$' } `
                | ForEach-Object { [int]$_ - 1 }

            $aIndices | ForEach-Object {
                if ($_ -ge 0 -and $_ -lt $releaseData.assets.Count) {
                    $releaseData.assets[$_]
                }
            }
        }

        if ($selectedAssets) {
            $downloadQueue += foreach ($asset in $selectedAssets) {
                @{
                    Url = $asset.browser_download_url
                    FileName = Join-Path $downloadsFolder $asset.name
                    Repo = "$($owner)/$($repoName)"
                }
            }
        } else {
            Write-Host "No valid asset selections for $($owner)/$($repoName)."
        }
    }
    catch {
        Write-Host "Error processing $($owner)/$($repoName): $($_.Exception.Message)"
    }
}

# Download all selected assets
foreach ($downloadItem in $downloadQueue) {
    Write-Host "`nDownloading $($downloadItem.FileName) from $($downloadItem.Repo)..."
    try {
        Invoke-WebRequest -Uri $downloadItem.Url -OutFile $downloadItem.FileName -UseBasicParsing
        Write-Host "Downloaded: $($downloadItem.FileName)"
    }
    catch {
        Write-Host "Failed to download $($downloadItem.FileName). Error: $($_.Exception.Message)"
    }
}

Write-Host "`nAll downloads completed."
