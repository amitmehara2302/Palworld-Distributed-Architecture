# ==========================================
# 1. IMPORT BACKEND ENGINE (The Handshake)
# ==========================================
. (Join-Path $PSScriptRoot "PalEngine.ps1")

# ==========================================
# 2. BOOT SEQUENCE
# ==========================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null

Load-Env
Run-PreFlightChecks

# ==========================================
# 3. BUILD THE UI
# ==========================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Palworld Enterprise Dashboard"
$form.Size = New-Object System.Drawing.Size(400, 230)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$nameLabel = New-Object System.Windows.Forms.Label
$nameLabel.Location = New-Object System.Drawing.Point(20, 20)
$nameLabel.Size = New-Object System.Drawing.Size(100, 20)
$nameLabel.Text = "Host Name:"
$nameLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($nameLabel)

$nameBox = New-Object System.Windows.Forms.TextBox
$nameBox.Location = New-Object System.Drawing.Point(120, 18)
$nameBox.Size = New-Object System.Drawing.Size(240, 25)
$nameBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$nameBox.Text = $global:EnvVars["PLAYER_NAME"]
$form.Controls.Add($nameBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 50)
$statusLabel.Size = New-Object System.Drawing.Size(340, 20)
$statusLabel.Text = "Status: Idle"
$statusLabel.ForeColor = [System.Drawing.Color]::Blue
$form.Controls.Add($statusLabel)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(20, 80)
$startButton.Size = New-Object System.Drawing.Size(160, 60)
$startButton.Text = "START SERVER"
$startButton.BackColor = [System.Drawing.Color]::LightGreen
$startButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$startButton.Cursor = [System.Windows.Forms.Cursors]::Hand

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Location = New-Object System.Drawing.Point(200, 80)
$stopButton.Size = New-Object System.Drawing.Size(160, 60)
$stopButton.Text = "STOP AND BACKUP"
$stopButton.BackColor = [System.Drawing.Color]::LightCoral
$stopButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$stopButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$stopButton.Enabled = $false

# ==========================================
# 4. BIND EVENTS TO BACKEND
# ==========================================
$startButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($nameBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Arey bhau, naam toh likh de!", "Error", 0, 16)
            return
        } 
    
        Save-PlayerName $nameBox.Text
        $startButton.Enabled = $false
    
        if (Execute-StartProtocol $statusLabel $form) {
            $statusLabel.Text = "Status: [ONLINE] Server is LIVE and Breathing!"
            $statusLabel.ForeColor = [System.Drawing.Color]::Green
            $stopButton.Enabled = $true
        }
        else {
            $startButton.Enabled = $true
        }
    })

$stopButton.Add_Click({
        $stopButton.Enabled = $false
        Execute-StopProtocol $statusLabel $form
        $statusLabel.Text = "Status: [OFFLINE] Safely Backed Up."
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        $startButton.Enabled = $true
    })

$form.Controls.Add($startButton)
$form.Controls.Add($stopButton)

$form.Add_FormClosing({
        if ($stopButton.Enabled) {
            $result = [System.Windows.Forms.MessageBox]::Show("Wait! Server is still running. Auto-backup before closing?", "Emergency Protocol", 4, 48)
            if ($result -eq 'Yes') { Execute-StopProtocol $statusLabel $form } else { $_.Cancel = $true }
        }
    })

# Startup Check
if (Check-ServerHealth) {
    $statusLabel.Text = "Status: [ONLINE] Server is currently LIVE!"
    $statusLabel.ForeColor = [System.Drawing.Color]::Green
    $startButton.Enabled = $false
    $stopButton.Enabled = $true
}

$form.Topmost = $true
$form.ShowDialog() | Out-Null