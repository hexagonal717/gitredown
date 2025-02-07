function ShowHeading {
    Clear-Host
    Write-Host "==============================="
    Write-Host "   GitReDown by hexagonal717"
    Write-Host "==============================="
}

function Show-AssetMenu {
    param (
        [array]$assets,
        [string]$repoName
    )
    while ($true) {
        Clear-Host
        $menuOptions = @()
        for ($i = 0; $i -lt $assets.Count; $i++) {
            # Only display the asset name instead of the entire object
            $menuOptions += "$($i+1). $($assets[$i].name)"
        }
        $menuOptions += "b. Go Back"

        ShowHeading
        Write-Host "Repository: $repoName"
        $menuOptions | ForEach-Object { Write-Host $_ }

        $selection = Read-Host "`nEnter asset numbers to download (comma-separated), 'all'"
        if ($selection -eq 'b') {
            return
        } else {
            Download-Assets -repoName $repoName -assets $assets -selection $selection
        }
    }
}

function Download-Assets {
    param (
        [string]$repoName,
        [array]$assets,
        [string]$selection
    )

    if ($selection -eq 'all') {
        $selectedAssets = $assets
    } else {
        $indices = ($selection -split ',') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^\d+$' } |
            ForEach-Object { [int]$_ - 1 } |
            Where-Object { $_ -ge 0 -and $_ -lt $assets.Count }

        $selectedAssets = $indices | ForEach-Object { $assets[$_] }
    }

    if ($selectedAssets) {
        foreach ($asset in $selectedAssets) {
            Write-Host "Downloading $($asset.name) from $repoName..."
            try {
                $outFile = Join-Path $downloadsFolder $asset.name
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $outFile -UseBasicParsing
                Write-Host "Successfully downloaded: $($asset.name)"
            } catch {
                Write-Host "Failed to download $($asset.name): $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "No valid assets selected."
    }

    Write-Host "`nPress Enter to continue..."
    Read-Host
}

# Rest of the original script...
$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentFolder = Split-Path $scriptFolder -Parent
$downloadsFolder = Join-Path $parentFolder "downloads"
$jsonFile = Join-Path $scriptFolder "repos.json"

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
    $repoList = @($repoList)
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

do {
    ShowHeading
    Write-Host "Found $($repoList.Count) repositories."
    for ($i = 0; $i -lt $repoList.Count; $i++) {
        Write-Host "$($i + 1). $($repoList[$i].Owner)/$($repoList[$i].Name)"
    }

    $repoSelection = Read-Host "`nEnter repo numbers to process (comma-separated) or type 'all'"

    if ($repoSelection -eq 'all') {
        $selectedRepos = $repoList
    } else {
        $indices = ($repoSelection -split ',') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^\d+$' } |
            ForEach-Object { [int]$_ - 1 } |
            Where-Object { $_ -ge 0 -and $_ -lt $repoList.Count }

        if ($indices.Count -eq 0) {
            Write-Host "No valid repository selections."
            Read-Host "Press Enter to exit..."
            return
        }

        $selectedRepos = foreach ($idx in $indices) { $repoList[$idx] }
    }

    foreach ($repo in $selectedRepos) {
        $owner = $repo.Owner.Trim()
        $repoName = $repo.Name.Trim()
        $apiUrl = "https://api.github.com/repos/$($owner)/$($repoName)/releases/latest"

        Clear-Host
        ShowHeading
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

            Show-AssetMenu -assets $releaseData.assets -repoName "$owner/$repoName"
        }
        catch {
            Write-Host "Error processing $($owner)/$($repoName): $($_.Exception.Message)"
        }
    }
} while ($true)