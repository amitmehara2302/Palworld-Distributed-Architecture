# ==========================================
# BACKEND ENGINE (Logic, Docker, Logs)
# ==========================================
$global:EnvVars = @{}

function Load-Env {
    $envFilePath = Join-Path $PSScriptRoot ".env"
    if (-not (Test-Path $envFilePath)) {
        [System.Windows.Forms.MessageBox]::Show("FATAL: .env file missing!", "Error", 0, 16)
        exit
    }
    Get-Content $envFilePath | Where-Object { $_ -match '^\s*([^#]+?)\s*=\s*"?([^"]*?)"?\s*$' } | ForEach-Object {
        $global:EnvVars[$Matches[1]] = $Matches[2]
        [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process")
    }
}

function Save-PlayerName([string]$NewName) {
    $envFilePath = Join-Path $PSScriptRoot ".env"
    $content = Get-Content $envFilePath
    $content = $content -replace '^PLAYER_NAME=.*', "PLAYER_NAME=`"$NewName`""
    $content | Set-Content $envFilePath
    $global:EnvVars["PLAYER_NAME"] = $NewName
}

# 📝 THE GATEKEEPER LOG STRATEGY
function Write-Log([string]$Message) {
    # If the master switch is off, drop the log immediately!
    if ($global:EnvVars["LOGGING"] -ne "true") { return }

    $CloudFolder = $global:EnvVars["SHARED_CLOUD_FOLDER"]
    $CloudLogDir = Join-Path $CloudFolder "Logs"
    
    if (-not (Test-Path $CloudLogDir)) { New-Item -ItemType Directory -Path $CloudLogDir | Out-Null }

    $DateStamp = Get-Date -Format "yyyy-MM-dd"
    $DailyLogFile = Join-Path $CloudLogDir "palworld-$DateStamp.log"

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    $LogEntry | Out-File -FilePath $DailyLogFile -Append
}

function Run-PreFlightChecks {
    $dockerCheck = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        [System.Windows.Forms.MessageBox]::Show("Arey vedya! Docker Desktop is not running. Please start Docker first.", "Pre-Flight Error", 0, 16)
        exit
    }
    $cloudFolder = $global:EnvVars["SHARED_CLOUD_FOLDER"]
    if (-not (Test-Path $cloudFolder)) {
        [System.Windows.Forms.MessageBox]::Show("G-Drive folder not found at: $cloudFolder", "Pre-Flight Error", 0, 16)
        exit
    }
}

function Send-DiscordMessage([string]$Message) {
    $url = $global:EnvVars["DISCORD_WEBHOOK_URL"]
    if ([string]::IsNullOrWhiteSpace($url) -or $url -match "your_webhook_here") { return }
    $Payload = @{ content = $Message } | ConvertTo-Json
    try { Invoke-RestMethod -Uri $url -Method Post -Body $Payload -ContentType 'application/json' -TimeoutSec 5 -ErrorAction Stop } catch { }
}

function Check-ServerHealth {
    $status = docker inspect -f '{{.State.Status}}' palworld-squad 2>&1
    return ($status -match "running")
}

function Execute-StartProtocol($StatusLabel, $Form) {
    Write-Log "=== START PROTOCOL INITIATED BY $($global:EnvVars['PLAYER_NAME']) ==="

    $StatusLabel.Text = "Status: Starting... UI will freeze briefly."
    $Form.Refresh()

    $LockFile = Join-Path $global:EnvVars["SHARED_CLOUD_FOLDER"] "server.lock"
    if (Test-Path $LockFile) {
        $HostedBy = Get-Content $LockFile
        Write-Log "[ERROR] Failed to start. Server already locked by $HostedBy."
        [System.Windows.Forms.MessageBox]::Show("Server is already locked by: $HostedBy", "Lock Error", 0, 16)
        $StatusLabel.Text = "Status: Idle"
        return $false
    }

    $global:EnvVars["PLAYER_NAME"] | Out-File -FilePath $LockFile
    Write-Log "[SUCCESS] Lock acquired."
    
    $CloudBackup = Join-Path $global:EnvVars["SHARED_CLOUD_FOLDER"] "Backups"
    $LocalBackup = Join-Path $PSScriptRoot "LocalBackups"
    if (-not (Test-Path $LocalBackup)) { New-Item -ItemType Directory -Path $LocalBackup | Out-Null }

    $LatestBackup = Get-ChildItem -Path $CloudBackup -Filter "*.tar.gz" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($LatestBackup) {
        Write-Log "[INFO] Found cloud backup. Extracting..."
        $LocalStagingPath = Join-Path $LocalBackup $LatestBackup.Name
        Copy-Item -Path $LatestBackup.FullName -Destination $LocalStagingPath -Force
        $CmdString = "rm -rf /data/* ; tar -xzf '/backup/{0}' -C /data" -f $LatestBackup.Name
        
        $extractOut = docker run --rm -v "palworld_data:/data" -v "${LocalBackup}:/backup" alpine sh -c $CmdString 2>&1 | ForEach-Object { "$_" }
        if ($extractOut) { Write-Log ($extractOut -join "`n") }
    }

    Write-Log "[INFO] Igniting Pocketpair Engine via Compose..."
    $upOut = docker compose up -d 2>&1 | ForEach-Object { "$_" }
    if ($upOut) { Write-Log ($upOut -join "`n") }

    $retries = 0
    while (-not (Check-ServerHealth) -and $retries -lt 5) {
        Start-Sleep -Seconds 3
        $retries++
    }

    if (Check-ServerHealth) {
        Write-Log "[SUCCESS] Server is LIVE."
        Send-DiscordMessage "[SUCCESS] $($global:EnvVars['PLAYER_NAME']) booted the server. Password is required!"
        return $true
    }
    else {
        Write-Log "[FATAL] Engine failed health check. Aborting."
        [System.Windows.Forms.MessageBox]::Show("Engine failed to ignite properly. Check Logs folder.", "Health Check Failed", 0, 16)
        Remove-Item $LockFile -ErrorAction SilentlyContinue
        return $false
    }
}

function Execute-StopProtocol($StatusLabel, $Form) {
    Write-Log "=== STOP PROTOCOL INITIATED BY $($global:EnvVars['PLAYER_NAME']) ==="

    $StatusLabel.Text = "Status: Backing up... PLEASE DO NOT CLOSE."
    $Form.Refresh()

    Write-Log "[INFO] Gracefully stopping container..."
    $stopOut = docker compose stop 2>&1 | ForEach-Object { "$_" }
    if ($stopOut) { Write-Log ($stopOut -join "`n") }

    $LocalBackup = Join-Path $PSScriptRoot "LocalBackups"
    $CloudBackup = Join-Path $global:EnvVars["SHARED_CLOUD_FOLDER"] "Backups"
    $BackupName = "Palworld_Save_{0}.tar.gz" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    
    Write-Log "[INFO] Zipping data to local staging..."
    $zipOut = docker run --rm -v "palworld_data:/data" -v "${LocalBackup}:/backup" alpine tar -czf "/backup/$BackupName" -C /data . 2>&1 | ForEach-Object { "$_" }
    if ($zipOut) { Write-Log ($zipOut -join "`n") }
    
    Write-Log "[INFO] Uploading backup to Google Drive..."
    Copy-Item -Path (Join-Path $LocalBackup $BackupName) -Destination (Join-Path $CloudBackup $BackupName) -Force
    
    Write-Log "[INFO] Trashing container and volume..."
    $downOut = docker compose down -v 2>&1 | ForEach-Object { "$_" }
    if ($downOut) { Write-Log ($downOut -join "`n") }
    
    $LockFile = Join-Path $global:EnvVars["SHARED_CLOUD_FOLDER"] "server.lock"
    if (Test-Path $LockFile) { Remove-Item $LockFile -ErrorAction SilentlyContinue }

    Write-Log "[SUCCESS] Operations complete. Lock released."
    Send-DiscordMessage "[INFO] $($global:EnvVars['PLAYER_NAME']) safely stopped the server."
}