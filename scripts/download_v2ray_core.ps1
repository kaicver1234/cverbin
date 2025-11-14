# PowerShell script to download V2Ray core for Windows

$ErrorActionPreference = "Stop"

# Configuration
$V2RAY_VERSION = "latest"
$DOWNLOAD_URL = "https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-windows-64.zip"
$ASSETS_DIR = Join-Path $PSScriptRoot "..\assets\v2ray-core"
$TEMP_ZIP = Join-Path $env:TEMP "v2ray-windows-64.zip"
$TEMP_EXTRACT = Join-Path $env:TEMP "v2ray-extract"

Write-Host "Downloading V2Ray Core for Windows..." -ForegroundColor Cyan
Write-Host ""

# Create assets directory if it doesn't exist
if (-not (Test-Path $ASSETS_DIR)) {
    New-Item -ItemType Directory -Path $ASSETS_DIR -Force | Out-Null
    Write-Host "[OK] Created assets directory" -ForegroundColor Green
}

# Check if files already exist
$v2rayExe = Join-Path $ASSETS_DIR "v2ray.exe"
if (Test-Path $v2rayExe) {
    Write-Host "[WARNING] V2Ray core already exists in assets" -ForegroundColor Yellow
    $response = Read-Host "Do you want to re-download? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "[CANCELLED]" -ForegroundColor Red
        exit 0
    }
}

# Download V2Ray core
Write-Host "[DOWNLOAD] Downloading from GitHub..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $TEMP_ZIP -UseBasicParsing
    Write-Host "[OK] Downloaded successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to download: $_" -ForegroundColor Red
    exit 1
}

# Extract files
Write-Host "[EXTRACT] Extracting files..." -ForegroundColor Cyan
try {
    # Remove old extraction directory if exists
    if (Test-Path $TEMP_EXTRACT) {
        Remove-Item -Path $TEMP_EXTRACT -Recurse -Force
    }
    
    # Extract zip
    Expand-Archive -Path $TEMP_ZIP -DestinationPath $TEMP_EXTRACT -Force
    Write-Host "[OK] Extracted successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to extract: $_" -ForegroundColor Red
    exit 1
}

# Copy required files
Write-Host "[COPY] Copying required files..." -ForegroundColor Cyan
$requiredFiles = @("v2ray.exe", "geoip.dat", "geosite.dat")

foreach ($file in $requiredFiles) {
    $sourcePath = Join-Path $TEMP_EXTRACT $file
    $destPath = Join-Path $ASSETS_DIR $file
    
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        $fileSize = (Get-Item $destPath).Length / 1MB
        $fileSizeRounded = [math]::Round($fileSize, 2)
        Write-Host "  [OK] $file ($fileSizeRounded MB)" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] $file not found in archive" -ForegroundColor Yellow
    }
}

# Cleanup
Write-Host "[CLEANUP] Cleaning up..." -ForegroundColor Cyan
Remove-Item -Path $TEMP_ZIP -Force -ErrorAction SilentlyContinue
Remove-Item -Path $TEMP_EXTRACT -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[OK] Cleanup complete" -ForegroundColor Green

Write-Host ""
Write-Host "[SUCCESS] V2Ray Core setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Files location: $ASSETS_DIR" -ForegroundColor Cyan
Write-Host ""
