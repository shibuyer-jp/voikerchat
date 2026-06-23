# Voikerchat GitHub Auto-Push Script (PowerShell)
# 
# Location: %USERPROFILE%\Documents\Voikerchat\scripts\push-commits.ps1
# Usage: powershell -ExecutionPolicy Bypass -File push-commits.ps1
#
# This script retrieves the GitHub PAT from Google Drive (via environment)
# and automatically pushes commits to GitHub.

param(
    [Parameter(Mandatory=$false)]
    [string]$PAT = $env:GITHUB_TOKEN
)

function Write-Status {
    param([string]$Message, [string]$Status = "INFO")
    $colors = @{
        "OK"    = "Green"
        "ERROR" = "Red"
        "WARN"  = "Yellow"
        "INFO"  = "Cyan"
    }
    Write-Host "[$Status] $Message" -ForegroundColor $colors[$Status]
}

function Test-GitRemote {
    param([string]$URL)
    try {
        git ls-remote $URL 2>&1 | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Header
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Voikerchat GitHub Auto-Push" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify project directory
$projectDir = Split-Path -Parent $PSScriptRoot
$gitDir = Join-Path $projectDir ".git"

if (-not (Test-Path $gitDir)) {
    Write-Status "Error: Not a git repository" "ERROR"
    exit 1
}

Write-Status "Project directory: $projectDir" "INFO"
Set-Location $projectDir

# Step 2: Get GitHub PAT
Write-Status "Retrieving GitHub PAT..." "INFO"

if ([string]::IsNullOrEmpty($PAT)) {
    Write-Host "GitHub PAT not found in environment variable GITHUB_TOKEN"
    Write-Host ""
    Write-Host "Option 1: Set environment variable and re-run"
    Write-Host "  `$env:GITHUB_TOKEN = 'ghp_...'"
    Write-Host "  powershell -ExecutionPolicy Bypass -File push-commits.ps1"
    Write-Host ""
    Write-Host "Option 2: Retrieve PAT from Google Drive"
    Write-Host "  1. Open: https://drive.google.com"
    Write-Host "  2. Navigate: 00_Project_Credentials/API_Keys"
    Write-Host "  3. Open: Github_API_Key.txt"
    Write-Host "  4. Copy token (starts with ghp_)"
    Write-Host ""
    $PAT = Read-Host "Enter GitHub PAT"
}

# Validate PAT format
if (-not ($PAT -match '^ghp_[a-zA-Z0-9_]{36,}$')) {
    Write-Status "Invalid PAT format (must start with ghp_)" "ERROR"
    exit 1
}

Write-Status "PAT received (${PAT.Substring(0,10)}...)" "OK"
Write-Host ""

# Step 3: Update git remote URL
Write-Status "Updating git remote URL..." "INFO"

$remoteURL = "https://${PAT}@github.com/shibuyer-jp/voikerchat.git"
git remote set-url origin $remoteURL

Write-Status "Remote URL updated" "OK"
Write-Host ""

# Step 4: Test connectivity
Write-Status "Testing GitHub connectivity..." "INFO"

if (Test-GitRemote $remoteURL) {
    Write-Status "GitHub connection verified" "OK"
} else {
    Write-Status "GitHub connection failed - check PAT" "ERROR"
    exit 1
}

Write-Host ""

# Step 5: Get branch and commit count
$branch = git rev-parse --abbrev-ref HEAD
Write-Status "Current branch: $branch" "INFO"

$commitCount = & {
    $output = git rev-list --count "origin/$branch..$branch" 2>&1
    if ($LASTEXITCODE -eq 0) { return $output } else { return 0 }
}

if ($commitCount -eq 0) {
    Write-Status "No commits to push (already synchronized)" "WARN"
    exit 0
}

Write-Status "Commits to push: $commitCount" "INFO"
Write-Host ""

# Step 6: Execute push
Write-Status "Pushing commits to GitHub..." "INFO"

git push origin $branch
if ($LASTEXITCODE -ne 0) {
    Write-Status "Push failed" "ERROR"
    exit 1
}

Write-Status "Push successful!" "OK"
Write-Host ""

# Step 7: Verify push
Write-Status "Verifying push..." "INFO"

$unpushedCommits = & {
    $output = git rev-list --count "origin/$branch..$branch" 2>&1
    if ($LASTEXITCODE -eq 0) { return $output } else { return 0 }
}

if ($unpushedCommits -eq 0) {
    Write-Status "All commits successfully pushed" "OK"
}

Write-Host ""
Write-Host "Latest commits:" -ForegroundColor Cyan
git log --oneline -3

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ Voikerchat Push Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository: https://github.com/shibuyer-jp/voikerchat" -ForegroundColor Green
Write-Host "Branch: $branch" -ForegroundColor Green
