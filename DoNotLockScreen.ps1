Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- State ---
$script:nbre          = 0
$script:startTime     = Get-Date
$script:nextPressTime = $null
$WShell = New-Object -com "Wscript.Shell"

# --- Palette ---
$bgColor    = [System.Drawing.Color]::FromArgb(15, 15, 15)
$panelColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
$accent     = [System.Drawing.Color]::FromArgb(167, 139, 250)
$green      = [System.Drawing.Color]::FromArgb(52, 211, 153)
$red        = [System.Drawing.Color]::FromArgb(248, 113, 113)
$textColor  = [System.Drawing.Color]::FromArgb(229, 229, 231)
$muted      = [System.Drawing.Color]::FromArgb(113, 113, 122)

# --- Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text            = "DoNotLockScreen"
$form.ClientSize      = New-Object System.Drawing.Size(460, 380)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = $bgColor

# --- Header ---
$lblTitle           = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "DoNotLockScreen"
$lblTitle.Font      = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $accent
$lblTitle.Location  = New-Object System.Drawing.Point(16, 14)
$lblTitle.AutoSize  = $true
$form.Controls.Add($lblTitle)

$lblStatus           = New-Object System.Windows.Forms.Label
$lblStatus.Text      = "* Active"
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatus.ForeColor = $green
$lblStatus.Location  = New-Object System.Drawing.Point(16, 42)
$lblStatus.AutoSize  = $true
$form.Controls.Add($lblStatus)

# --- Stats panel ---
$statsPanel          = New-Object System.Windows.Forms.Panel
$statsPanel.Location = New-Object System.Drawing.Point(12, 68)
$statsPanel.Size     = New-Object System.Drawing.Size(436, 78)
$statsPanel.BackColor = $panelColor
$form.Controls.Add($statsPanel)

function New-StatBlock($parent, $x, $labelText, $initialValue) {
    $lbl           = New-Object System.Windows.Forms.Label
    $lbl.Text      = $labelText
    $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
    $lbl.ForeColor = $muted
    $lbl.Location  = New-Object System.Drawing.Point($x, 10)
    $lbl.AutoSize  = $true
    $parent.Controls.Add($lbl)

    $val           = New-Object System.Windows.Forms.Label
    $val.Text      = $initialValue
    $val.Font      = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $val.ForeColor = $textColor
    $val.Location  = New-Object System.Drawing.Point($x, 26)
    $val.AutoSize  = $true
    $parent.Controls.Add($val)

    return $val
}

$lblIterCount = New-StatBlock $statsPanel 16  "Iterations" "0"
$lblUptime    = New-StatBlock $statsPanel 155 "Uptime"     "00:00:00"
$lblCountdown = New-StatBlock $statsPanel 310 "Next press" "2:00"

# --- Log area ---
$lblLogHeader           = New-Object System.Windows.Forms.Label
$lblLogHeader.Text      = "Log"
$lblLogHeader.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblLogHeader.ForeColor = $muted
$lblLogHeader.Location  = New-Object System.Drawing.Point(16, 160)
$lblLogHeader.AutoSize  = $true
$form.Controls.Add($lblLogHeader)

$rtb             = New-Object System.Windows.Forms.RichTextBox
$rtb.Location    = New-Object System.Drawing.Point(12, 178)
$rtb.Size        = New-Object System.Drawing.Size(436, 188)
$rtb.BackColor   = $panelColor
$rtb.ForeColor   = $textColor
$rtb.Font        = New-Object System.Drawing.Font("Consolas", 9)
$rtb.ReadOnly    = $true
$rtb.BorderStyle = "None"
$rtb.ScrollBars  = "Vertical"
$form.Controls.Add($rtb)

function Write-Log($text, $color) {
    $rtb.SelectionStart  = $rtb.TextLength
    $rtb.SelectionLength = 0
    $rtb.SelectionColor  = $color
    $rtb.AppendText("$text`n")
    $rtb.ScrollToCaret()
}

# --- Main action ---
function Invoke-Press {
    $script:nbre++
    $date = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    try {
        $WShell.SendKeys("{PRTSC}")
        Start-Sleep -Milliseconds 100
        Write-Log "[$($script:nbre)] $date" $green
    } catch {
        Write-Log "[$($script:nbre)] $date  --  Error" $red
    }
    $lblIterCount.Text    = "$($script:nbre)"
    $script:nextPressTime = (Get-Date).AddSeconds(120)
}

# --- Main timer: every 2 minutes ---
$mainTimer          = New-Object System.Windows.Forms.Timer
$mainTimer.Interval = 120000
$mainTimer.Add_Tick({ Invoke-Press })

# --- UI timer: every second ---
$uiTimer          = New-Object System.Windows.Forms.Timer
$uiTimer.Interval = 1000
$uiTimer.Add_Tick({
    $elapsed = (Get-Date) - $script:startTime
    $h = [math]::Floor($elapsed.TotalHours)
    $lblUptime.Text = "{0:D2}:{1:D2}:{2:D2}" -f $h, $elapsed.Minutes, $elapsed.Seconds

    if ($null -ne $script:nextPressTime) {
        $rem = $script:nextPressTime - (Get-Date)
        if ($rem.TotalSeconds -gt 0) {
            $lblCountdown.Text = "{0}:{1:D2}" -f $rem.Minutes, $rem.Seconds
        } else {
            $lblCountdown.Text = "0:00"
        }
    }
})

# --- Start ---
$form.Add_Shown({
    $started = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    Write-Log "Session started on $started" $muted
    Invoke-Press
    $mainTimer.Start()
    $uiTimer.Start()
})

$form.Add_FormClosing({
    $mainTimer.Stop()
    $uiTimer.Stop()
})

[System.Windows.Forms.Application]::Run($form)
