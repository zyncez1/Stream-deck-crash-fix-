# Stream Deck Auto-Recover v0.3
# Hidden PowerShell host + real Windows system tray icon.
# No .NET SDK required.

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Prevent PowerShell from exiting while WinForms is active.
[System.Windows.Forms.Application]::EnableVisualStyles()

$cfgMgrSource = @"
using System;
using System.Runtime.InteropServices;

public static class DevicePresence
{
    private const uint CR_SUCCESS = 0;
    private const uint CM_LOCATE_DEVNODE_NORMAL = 0x00000000;

    [DllImport("CfgMgr32.dll", CharSet = CharSet.Unicode)]
    private static extern uint CM_Locate_DevNodeW(
        out uint pdnDevInst,
        string pDeviceID,
        uint ulFlags);

    public static bool IsPresent(string instanceId)
    {
        if (String.IsNullOrWhiteSpace(instanceId))
            return false;

        uint devInst;
        return CM_Locate_DevNodeW(
            out devInst,
            instanceId,
            CM_LOCATE_DEVNODE_NORMAL) == CR_SUCCESS;
    }
}
"@

try {
    Add-Type -TypeDefinition $cfgMgrSource -Language CSharp -ErrorAction Stop
}
catch {
    if (-not ("DevicePresence" -as [type])) {
        throw
    }
}

$settingsDir = Join-Path $env:APPDATA 'StreamDeckAutoRecover'
$settingsFile = Join-Path $settingsDir 'settings.json'

function Load-Settings {
    if (Test-Path $settingsFile) {
        try {
            return Get-Content $settingsFile -Raw | ConvertFrom-Json
        }
        catch {}
    }

    return [pscustomobject]@{
        SelectedInstanceId = ''
        DisconnectSeconds = 3.0
        AutoStartMonitoring = $false
    }
}

function Save-Settings {
    try {
        if (-not (Test-Path $settingsDir)) {
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        }

        $selectedId = ''
        if ($deviceCombo.SelectedItem) {
            $selectedId = [string]$deviceCombo.SelectedItem.InstanceId
        }

        [pscustomobject]@{
            SelectedInstanceId = $selectedId
            DisconnectSeconds = [double]$threshold.Value
            AutoStartMonitoring = [bool]$autoStart.Checked
        } | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding UTF8
    }
    catch {}
}

function Find-StreamDeckDevices {
    param([string]$SavedId)

    $devices = @()

    try {
        $all = Get-PnpDevice -PresentOnly -ErrorAction Stop

        foreach ($d in $all) {
            $friendly = [string]$d.FriendlyName
            $instanceId = [string]$d.InstanceId
            $className = [string]$d.Class

            $blob = "$friendly $className $instanceId"

            if (
                $blob -match '(?i)stream\s*deck' -or
                $blob -match '(?i)elgato' -or
                $instanceId -match '(?i)VID_0FD9'
            ) {
                $displayName = $friendly
                if ([string]::IsNullOrWhiteSpace($displayName)) {
                    $displayName = '(Unnamed Elgato/Stream Deck device)'
                }

                $devices += [pscustomobject]@{
                    Display = "$displayName  [$className]"
                    FriendlyName = $displayName
                    InstanceId = $instanceId
                    Class = $className
                    Status = [string]$d.Status
                }
            }
        }
    }
    catch {
        throw "Could not enumerate Windows Plug-and-Play devices: $($_.Exception.Message)"
    }

    if (
        -not [string]::IsNullOrWhiteSpace($SavedId) -and
        -not ($devices | Where-Object { $_.InstanceId -eq $SavedId })
    ) {
        $devices += [pscustomobject]@{
            Display = 'Saved Stream Deck (currently unavailable)'
            FriendlyName = 'Saved Stream Deck (currently unavailable)'
            InstanceId = $SavedId
            Class = 'Saved device'
            Status = 'Unavailable'
        }
    }

    return @($devices | Sort-Object Display, InstanceId)
}

function Invoke-PnpUtil {
    param([Parameter(Mandatory=$true)][string[]]$Arguments)

    $pnputil = Join-Path $env:WINDIR 'System32\pnputil.exe'
    $output = & $pnputil @Arguments 2>&1 | Out-String
    $code = $LASTEXITCODE

    return [pscustomobject]@{
        ExitCode = $code
        Output = $output.Trim()
    }
}

function Reset-ExactDevice {
    param([string]$InstanceId)

    Log-Line 'DISABLE exact device ID:'
    Log-Line $InstanceId

    $disable = Invoke-PnpUtil -Arguments @('/disable-device', $InstanceId)
    Log-Line "Disable exit code: $($disable.ExitCode)"
    if ($disable.Output) { Log-Line $disable.Output }

    Start-Sleep -Milliseconds 1250

    $enable = Invoke-PnpUtil -Arguments @('/enable-device', $InstanceId)
    Log-Line "Enable exit code: $($enable.ExitCode)"
    if ($enable.Output) { Log-Line $enable.Output }

    $scan = Invoke-PnpUtil -Arguments @('/scan-devices')
    Log-Line "Rescan exit code: $($scan.ExitCode)"
    if ($scan.Output) { Log-Line $scan.Output }

    return ($enable.ExitCode -eq 0)
}

# ---------------- UI ----------------

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Stream Deck Auto-Recover v0.3'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(790, 640)
$form.MinimumSize = New-Object System.Drawing.Size(700, 560)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$form.ShowInTaskbar = $true

$intro = New-Object System.Windows.Forms.Label
$intro.Location = New-Object System.Drawing.Point(20, 18)
$intro.Size = New-Object System.Drawing.Size(735, 48)
$intro.Text = 'Choose the exact Stream Deck device to protect. Only that saved Windows device instance ID will be monitored or reset.'
$form.Controls.Add($intro)

$deviceLabel = New-Object System.Windows.Forms.Label
$deviceLabel.Location = New-Object System.Drawing.Point(20, 76)
$deviceLabel.Size = New-Object System.Drawing.Size(180, 24)
$deviceLabel.Text = 'Stream Deck device:'
$form.Controls.Add($deviceLabel)

$deviceCombo = New-Object System.Windows.Forms.ComboBox
$deviceCombo.Location = New-Object System.Drawing.Point(20, 102)
$deviceCombo.Size = New-Object System.Drawing.Size(575, 30)
$deviceCombo.DropDownStyle = 'DropDownList'
$deviceCombo.DisplayMember = 'Display'
$form.Controls.Add($deviceCombo)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Point(610, 100)
$refreshButton.Size = New-Object System.Drawing.Size(145, 32)
$refreshButton.Text = 'Refresh devices'
$form.Controls.Add($refreshButton)

$instanceLabel = New-Object System.Windows.Forms.Label
$instanceLabel.Location = New-Object System.Drawing.Point(20, 140)
$instanceLabel.Size = New-Object System.Drawing.Size(735, 48)
$instanceLabel.Text = 'Instance ID: none selected'
$form.Controls.Add($instanceLabel)

$thresholdText = New-Object System.Windows.Forms.Label
$thresholdText.Location = New-Object System.Drawing.Point(20, 196)
$thresholdText.Size = New-Object System.Drawing.Size(420, 28)
$thresholdText.Text = 'Reset only after selected device is absent for:'
$form.Controls.Add($thresholdText)

$threshold = New-Object System.Windows.Forms.NumericUpDown
$threshold.Location = New-Object System.Drawing.Point(445, 194)
$threshold.Size = New-Object System.Drawing.Size(85, 30)
$threshold.DecimalPlaces = 1
$threshold.Increment = 0.5
$threshold.Minimum = 1.0
$threshold.Maximum = 30.0
$threshold.Value = 3.0
$form.Controls.Add($threshold)

$secondsLabel = New-Object System.Windows.Forms.Label
$secondsLabel.Location = New-Object System.Drawing.Point(540, 196)
$secondsLabel.Size = New-Object System.Drawing.Size(100, 28)
$secondsLabel.Text = 'seconds'
$form.Controls.Add($secondsLabel)

$monitorButton = New-Object System.Windows.Forms.Button
$monitorButton.Location = New-Object System.Drawing.Point(20, 240)
$monitorButton.Size = New-Object System.Drawing.Size(165, 38)
$monitorButton.Text = 'Start monitoring'
$form.Controls.Add($monitorButton)

$testButton = New-Object System.Windows.Forms.Button
$testButton.Location = New-Object System.Drawing.Point(200, 240)
$testButton.Size = New-Object System.Drawing.Size(235, 38)
$testButton.Text = 'Test reset selected device'
$form.Controls.Add($testButton)

$autoStart = New-Object System.Windows.Forms.CheckBox
$autoStart.Location = New-Object System.Drawing.Point(20, 292)
$autoStart.Size = New-Object System.Drawing.Size(500, 28)
$autoStart.Text = 'Start monitoring automatically when this app opens'
$form.Controls.Add($autoStart)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 330)
$statusLabel.Size = New-Object System.Drawing.Size(735, 30)
$statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$statusLabel.Text = 'Status: starting...'
$form.Controls.Add($statusLabel)

$safetyLabel = New-Object System.Windows.Forms.Label
$safetyLabel.Location = New-Object System.Drawing.Point(20, 365)
$safetyLabel.Size = New-Object System.Drawing.Size(735, 45)
$safetyLabel.Text = 'Closing or minimizing this window sends it to the system tray. Use the tray icon menu to reopen it or exit completely.'
$form.Controls.Add($safetyLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 420)
$logBox.Size = New-Object System.Drawing.Size(735, 150)
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = 'Vertical'
$logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
$logBox.Anchor = 'Top,Bottom,Left,Right'
$form.Controls.Add($logBox)

function Log-Line {
    param([string]$Message)

    if ([string]::IsNullOrWhiteSpace($Message)) { return }

    foreach ($line in ($Message -split "`r?`n")) {
        $logBox.AppendText("[$(Get-Date -Format HH:mm:ss)] $line`r`n")
    }
}

$script:Monitoring = $false
$script:SeenConnected = $false
$script:WaitingForReconnect = $false
$script:RecoveryRunning = $false
$script:DisconnectStarted = $null
$script:SelectedInstanceId = ''
$script:ReallyExit = $false

# ---------------- System tray ----------------

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Application
$tray.Text = 'Stream Deck Auto-Recover'
$tray.Visible = $true

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip

$trayOpen = New-Object System.Windows.Forms.ToolStripMenuItem
$trayOpen.Text = 'Open Stream Deck Auto-Recover'
$trayMenu.Items.Add($trayOpen) | Out-Null

$trayToggle = New-Object System.Windows.Forms.ToolStripMenuItem
$trayToggle.Text = 'Start monitoring'
$trayMenu.Items.Add($trayToggle) | Out-Null

$trayMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$trayExit = New-Object System.Windows.Forms.ToolStripMenuItem
$trayExit.Text = 'Exit'
$trayMenu.Items.Add($trayExit) | Out-Null

$tray.ContextMenuStrip = $trayMenu

function Show-MainWindow {
    $form.Show()
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.ShowInTaskbar = $true
    $form.Activate()
    $form.BringToFront()
}

function Hide-ToTray {
    $form.Hide()
    $form.ShowInTaskbar = $false
}

$tray.Add_DoubleClick({ Show-MainWindow })
$trayOpen.Add_Click({ Show-MainWindow })

# ---------------- Settings ----------------

$settings = Load-Settings

try {
    $threshold.Value = [decimal]([Math]::Min(30, [Math]::Max(1, [double]$settings.DisconnectSeconds)))
}
catch {
    $threshold.Value = 3.0
}

try {
    $autoStart.Checked = [bool]$settings.AutoStartMonitoring
}
catch {}

function Refresh-DeviceList {
    if ($script:Monitoring) {
        [System.Windows.Forms.MessageBox]::Show(
            'Stop monitoring before changing the selected device.',
            'Stream Deck Auto-Recover',
            'OK',
            'Information'
        ) | Out-Null
        return
    }

    $refreshButton.Enabled = $false
    $deviceCombo.Enabled = $false
    $statusLabel.Text = 'Status: scanning for Stream Deck / Elgato devices...'

    try {
        $saved = ''
        try { $saved = [string]$settings.SelectedInstanceId } catch {}

        if ($deviceCombo.SelectedItem) {
            $saved = [string]$deviceCombo.SelectedItem.InstanceId
        }

        $devices = @(Find-StreamDeckDevices -SavedId $saved)

        $deviceCombo.DataSource = $null
        $deviceCombo.Items.Clear()

        if ($devices.Count -eq 0) {
            $instanceLabel.Text = 'Instance ID: none selected'
            $statusLabel.Text = 'Status: no Stream Deck / Elgato device found'
            Log-Line 'No matching device was found. Connect the Stream Deck and click Refresh devices.'
            return
        }

        $deviceCombo.DataSource = $devices
        $deviceCombo.DisplayMember = 'Display'

        $preferredIndex = 0
        for ($i = 0; $i -lt $devices.Count; $i++) {
            if ($devices[$i].InstanceId -eq $saved) {
                $preferredIndex = $i
                break
            }
        }

        $deviceCombo.SelectedIndex = $preferredIndex
        $statusLabel.Text = 'Status: ready'
        Log-Line "Found $($devices.Count) Stream Deck / Elgato device entr$(if($devices.Count -eq 1){'y'}else{'ies'})."
    }
    catch {
        $statusLabel.Text = 'Status: device scan failed'
        Log-Line $_.Exception.Message
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Device scan failed',
            'OK',
            'Error'
        ) | Out-Null
    }
    finally {
        $refreshButton.Enabled = $true
        $deviceCombo.Enabled = $true
    }
}

$deviceCombo.Add_SelectedIndexChanged({
    if ($deviceCombo.SelectedItem) {
        $script:SelectedInstanceId = [string]$deviceCombo.SelectedItem.InstanceId
        $instanceLabel.Text = "Instance ID: $($script:SelectedInstanceId)"
        Save-Settings
    }
})

$threshold.Add_ValueChanged({ Save-Settings })
$autoStart.Add_CheckedChanged({ Save-Settings })
$refreshButton.Add_Click({ Refresh-DeviceList })

function Update-TrayState {
    if ($script:Monitoring) {
        $trayToggle.Text = 'Stop monitoring'
        $tray.Text = 'Stream Deck Auto-Recover - Monitoring'
    }
    else {
        $trayToggle.Text = 'Start monitoring'
        $tray.Text = 'Stream Deck Auto-Recover - Idle'
    }
}

function Start-Monitoring {
    if (-not $deviceCombo.SelectedItem) {
        [System.Windows.Forms.MessageBox]::Show(
            'Select a Stream Deck device first.',
            'Stream Deck Auto-Recover',
            'OK',
            'Warning'
        ) | Out-Null
        return
    }

    $script:SelectedInstanceId = [string]$deviceCombo.SelectedItem.InstanceId

    $script:Monitoring = $true
    $script:SeenConnected = $false
    $script:WaitingForReconnect = $false
    $script:RecoveryRunning = $false
    $script:DisconnectStarted = $null

    $deviceCombo.Enabled = $false
    $refreshButton.Enabled = $false
    $threshold.Enabled = $false
    $testButton.Enabled = $false
    $monitorButton.Text = 'Stop monitoring'

    Save-Settings

    Log-Line "Monitoring ONLY: $($deviceCombo.SelectedItem.FriendlyName)"
    Log-Line "Exact Instance ID: $($script:SelectedInstanceId)"
    Log-Line "Threshold: $($threshold.Value) seconds"

    $timer.Start()
    $statusLabel.Text = 'Status: waiting to see selected device connected'
    Update-TrayState
}

function Stop-Monitoring {
    $timer.Stop()

    $script:Monitoring = $false
    $script:SeenConnected = $false
    $script:WaitingForReconnect = $false
    $script:RecoveryRunning = $false
    $script:DisconnectStarted = $null

    $deviceCombo.Enabled = $true
    $refreshButton.Enabled = $true
    $threshold.Enabled = $true
    $testButton.Enabled = $true
    $monitorButton.Text = 'Start monitoring'
    $statusLabel.Text = 'Status: not monitoring'

    Log-Line 'Monitoring stopped.'
    Update-TrayState
}

$monitorButton.Add_Click({
    if ($script:Monitoring) {
        Stop-Monitoring
    }
    else {
        Start-Monitoring
    }
})

$trayToggle.Add_Click({
    if ($script:Monitoring) {
        Stop-Monitoring
    }
    else {
        Start-Monitoring
    }
})

function Run-Recovery {
    param([string]$Reason)

    if ($script:RecoveryRunning) { return }

    $script:RecoveryRunning = $true
    $timer.Stop()

    try {
        $statusLabel.Text = 'Status: resetting selected Stream Deck...'
        $tray.Text = 'Stream Deck Auto-Recover - Recovering'
        Log-Line "$Reason"
        Log-Line 'Running disable -> 1.25 sec pause -> enable -> rescan.'

        $success = Reset-ExactDevice -InstanceId $script:SelectedInstanceId

        $script:WaitingForReconnect = $true
        $script:SeenConnected = $false
        $script:DisconnectStarted = $null

        if ($success) {
            Log-Line 'Recovery command completed. Waiting for exact selected device to reconnect.'
        }
        else {
            Log-Line 'Enable command failed. Verify this is the same Device Manager entry you normally reset.'
        }

        $statusLabel.Text = 'Status: recovery attempted — waiting for selected device'
    }
    catch {
        $script:WaitingForReconnect = $true
        $script:SeenConnected = $false
        $script:DisconnectStarted = $null

        Log-Line "Recovery error: $($_.Exception.Message)"
        $statusLabel.Text = 'Status: recovery error — waiting for selected device'
    }
    finally {
        $script:RecoveryRunning = $false
        if ($script:Monitoring) {
            $timer.Start()
        }
        Update-TrayState
    }
}

$testButton.Add_Click({
    if (-not $deviceCombo.SelectedItem) {
        [System.Windows.Forms.MessageBox]::Show(
            'Select a Stream Deck device first.',
            'Stream Deck Auto-Recover',
            'OK',
            'Warning'
        ) | Out-Null
        return
    }

    $script:SelectedInstanceId = [string]$deviceCombo.SelectedItem.InstanceId

    $answer = [System.Windows.Forms.MessageBox]::Show(
        "This will immediately disable and re-enable ONLY this selected device:`r`n`r`n$($deviceCombo.SelectedItem.FriendlyName)`r`n`r`n$($script:SelectedInstanceId)`r`n`r`nContinue?",
        'Test selected Stream Deck reset',
        'YesNo',
        'Warning'
    )

    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $testButton.Enabled = $false
    $monitorButton.Enabled = $false
    $refreshButton.Enabled = $false
    $deviceCombo.Enabled = $false

    try {
        $statusLabel.Text = 'Status: running manual test reset...'
        $tray.Text = 'Stream Deck Auto-Recover - Test reset'
        Log-Line 'MANUAL TEST'
        [void](Reset-ExactDevice -InstanceId $script:SelectedInstanceId)
        $statusLabel.Text = 'Status: manual test complete'
        Log-Line 'Manual test finished.'
    }
    catch {
        $statusLabel.Text = 'Status: manual test failed'
        Log-Line "Manual test error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Reset failed',
            'OK',
            'Error'
        ) | Out-Null
    }
    finally {
        $testButton.Enabled = $true
        $monitorButton.Enabled = $true
        $refreshButton.Enabled = $true
        $deviceCombo.Enabled = $true
        Update-TrayState
    }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250

$timer.Add_Tick({
    if (
        -not $script:Monitoring -or
        $script:RecoveryRunning -or
        [string]::IsNullOrWhiteSpace($script:SelectedInstanceId)
    ) {
        return
    }

    $present = [DevicePresence]::IsPresent($script:SelectedInstanceId)

    if ($present) {
        if (-not $script:SeenConnected) {
            $script:SeenConnected = $true
            Log-Line 'Selected device is connected. Watchdog armed.'
        }

        if ($script:WaitingForReconnect) {
            $script:WaitingForReconnect = $false
            Log-Line 'Selected device reconnected. Watchdog re-armed.'
        }

        $script:DisconnectStarted = $null
        $statusLabel.Text = 'Status: connected — monitoring'
        $tray.Text = 'Stream Deck Auto-Recover - Connected'
        return
    }

    if (-not $script:SeenConnected) {
        $statusLabel.Text = 'Status: selected device unavailable — waiting before arming'
        $tray.Text = 'Stream Deck Auto-Recover - Waiting for device'
        return
    }

    if ($script:WaitingForReconnect) {
        $statusLabel.Text = 'Status: recovery attempted — waiting for THIS device to reconnect'
        $tray.Text = 'Stream Deck Auto-Recover - Waiting for reconnect'
        return
    }

    if ($null -eq $script:DisconnectStarted) {
        $script:DisconnectStarted = [DateTime]::UtcNow
        Log-Line 'Selected device disappeared. Disconnect timer started.'
    }

    $elapsed = ([DateTime]::UtcNow - $script:DisconnectStarted).TotalSeconds
    $limit = [double]$threshold.Value

    if ($elapsed -lt $limit) {
        $statusLabel.Text = ('Status: selected device absent {0:N1}s / {1:N1}s' -f $elapsed, $limit)
        $tray.Text = ('Stream Deck Auto-Recover - Disconnected {0:N1}s' -f $elapsed)
        return
    }

    Run-Recovery -Reason 'AUTOMATIC RECOVERY: disconnect threshold reached.'
})

# Minimize => tray.
$form.Add_Resize({
    if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
        Hide-ToTray
    }
})

# X button => tray, not exit.
$form.Add_FormClosing({
    param($sender, $e)

    if (-not $script:ReallyExit) {
        $e.Cancel = $true
        Hide-ToTray

        $tray.ShowBalloonTip(
            1500,
            'Stream Deck Auto-Recover',
            $(if ($script:Monitoring) {
                'Still running and monitoring in the system tray.'
            } else {
                'Still running in the system tray.'
            }),
            [System.Windows.Forms.ToolTipIcon]::Info
        )
    }
})

$trayExit.Add_Click({
    $answer = [System.Windows.Forms.MessageBox]::Show(
        $(if ($script:Monitoring) {
            'Monitoring is currently active. Exit Stream Deck Auto-Recover completely?'
        } else {
            'Exit Stream Deck Auto-Recover completely?'
        }),
        'Exit Stream Deck Auto-Recover',
        'YesNo',
        'Question'
    )

    if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
        try { Save-Settings } catch {}
        $script:ReallyExit = $true
        $tray.Visible = $false
        $timer.Stop()
        $form.Close()
    }
})

# Initial load.
Refresh-DeviceList
Update-TrayState

if ($autoStart.Checked -and $deviceCombo.SelectedItem) {
    Start-Monitoring
}

# Show UI initially. PowerShell itself remains hidden.
$form.Add_Shown({
    $form.Activate()
})

[void]$form.ShowDialog()

# Cleanup after real exit.
$tray.Visible = $false
$tray.Dispose()
$timer.Dispose()
$form.Dispose()
