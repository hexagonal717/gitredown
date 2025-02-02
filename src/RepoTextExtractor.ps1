# -------------------------------------------------------------------
# 1) Paths
# -------------------------------------------------------------------
# This script's folder (e.g., C:\SomeProject\src)
try {
    $scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not $scriptFolder) {
        throw "Failed to determine the script's folder."
    }
} catch {
    Write-Host "ERROR: Unable to determine the script folder. $_"
    Read-Host "Press Enter to exit..."
    return
}

# The parent folder (e.g., C:\SomeProject)
try {
    $rootFolder = Split-Path $scriptFolder -Parent
    if (-not $rootFolder) {
        throw "Failed to determine the parent folder."
    }
} catch {
    Write-Host "ERROR: Unable to determine the parent folder. $_"
    Read-Host "Press Enter to exit..."
    return
}

# Path to repos.txt in the parent folder
$reposFile = Join-Path $rootFolder "repos.txt"

# Path to repos.json in the script folder
$jsonPath = Join-Path $scriptFolder "repos.json"

# Path to GithubReleaseDownloader.ps1 in the script folder
$downloaderScript = Join-Path $scriptFolder "GithubReleaseDownloader.ps1"

# Debugging: Output the constructed paths
Write-Host "Script folder: $scriptFolder"
Write-Host "Parent folder: $rootFolder"
Write-Host "Path to repos.txt: $reposFile"
Write-Host "Path to downloader script: $downloaderScript"

# -------------------------------------------------------------------
# 2) Read repos.txt, build array of repo objects
# -------------------------------------------------------------------
if (-not (Test-Path $reposFile)) {
    Write-Host "ERROR: 'repos.txt' not found at: $reposFile"
    Read-Host "Press Enter to exit..."
    return
}

Write-Host "Reading repos.txt from: $reposFile ..."
$lines = Get-Content -Path $reposFile -ErrorAction Stop

# We'll store each line as { Owner = "...", Name = "..." }
$repoObjects = @()

foreach ($line in $lines) {
    $trimmed = $line.Trim()
    # Match full URL like "https://github.com/Owner/Repo"
    if ($trimmed -match "^https://github\.com/([^/]+)/([^/]+)") {
        $owner    = $Matches[1]
        $repoName = $Matches[2]

        $repoObjects += [PSCustomObject]@{
            Owner = $owner
            Name  = $repoName
        }
    }
    # Match "Owner/Repo" format
    elseif ($trimmed -match "^([^/]+)/([^/]+)$") {
        $owner    = $Matches[1]
        $repoName = $Matches[2]

        $repoObjects += [PSCustomObject]@{
            Owner = $owner
            Name  = $repoName
        }
    }
    else {
        Write-Host "Skipping invalid line: '$line'"
    }
}

if ($repoObjects.Count -eq 0) {
    Write-Host "ERROR: No valid GitHub URLs or 'Owner/Repo' entries found in '$reposFile'."
    Read-Host "Press Enter to exit..."
    return
}

Write-Host "Found $($repoObjects.Count) valid repos."

# Convert to JSON
$jsonContent = $repoObjects | ConvertTo-Json -Depth 2

# Save JSON to file
Write-Host "`nWriting repos.json to: $jsonPath"
try {
    Set-Content -Path $jsonPath -Value $jsonContent -Encoding UTF8
    Write-Host "Successfully wrote repos.json."
} catch {
    Write-Host "Failed to write '$jsonPath': $($_.Exception.Message)"
    Read-Host "Press Enter to exit..."
    return
}

# -------------------------------------------------------------------
# 3) Invoke the downloader script
# -------------------------------------------------------------------
if (-not (Test-Path $downloaderScript)) {
    Write-Host "ERROR: Cannot find 'GithubReleaseDownloader.ps1' at: $downloaderScript"
    Read-Host "Press Enter to exit..."
    return
}

Write-Host "`nRunning GithubReleaseDownloader.ps1..."
try {
    # Use the call operator (&) to run the downloader script
    & $downloaderScript
    Write-Host "`nGithubReleaseDownloader.ps1 executed successfully."
} catch {
    Write-Host "ERROR: Failed to execute 'GithubReleaseDownloader.ps1'. $_"
    Read-Host "Press Enter to exit..."
    return
}

# -------------------------------------------------------------------
# Final Closing Message
# -------------------------------------------------------------------
Write-Host "`nAll operations are complete."
Read-Host "Press Enter to close..."