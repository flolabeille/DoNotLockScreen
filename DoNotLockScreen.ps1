Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- State ---
$script:nbre          = 0
$script:isRunning     = $false
$script:startTime     = $null
$script:nextPressTime = $null
$script:sessions      = @()
$WShell = New-Object -com "Wscript.Shell"

# --- Palette ---
$bgColor    = [System.Drawing.Color]::FromArgb(15, 15, 15)
$panelColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
$accent     = [System.Drawing.Color]::FromArgb(167, 139, 250)
$green      = [System.Drawing.Color]::FromArgb(52, 211, 153)
$red        = [System.Drawing.Color]::FromArgb(248, 113, 113)
$orange     = [System.Drawing.Color]::FromArgb(251, 146, 60)
$gold       = [System.Drawing.Color]::FromArgb(250, 204, 21)
$textColor  = [System.Drawing.Color]::FromArgb(229, 229, 231)
$muted      = [System.Drawing.Color]::FromArgb(113, 113, 122)
$white      = [System.Drawing.Color]::White

# --- Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text            = "DoNotLockScreen"
$form.ClientSize      = New-Object System.Drawing.Size(600, 520)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MinimumSize     = New-Object System.Drawing.Size(520, 430)
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
$lblStatus.Text      = "* Inactive"
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatus.ForeColor = $red
$lblStatus.Location  = New-Object System.Drawing.Point(16, 42)
$lblStatus.AutoSize  = $true
$form.Controls.Add($lblStatus)

# --- Button panel ---
$btnPanel          = New-Object System.Windows.Forms.FlowLayoutPanel
$btnPanel.Location = New-Object System.Drawing.Point(12, 68)
$btnPanel.Size     = New-Object System.Drawing.Size(576, 46)
$btnPanel.BackColor    = $bgColor
$btnPanel.Anchor       = [System.Windows.Forms.AnchorStyles]"Top,Left,Right"
$btnPanel.Padding      = New-Object System.Windows.Forms.Padding(0)
$btnPanel.WrapContents = $false
$form.Controls.Add($btnPanel)

function New-Btn($text, $bgClr, $fgClr, $w) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $text
    $b.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $bgClr
    $b.ForeColor = $fgClr
    $b.Size      = New-Object System.Drawing.Size($w, 38)
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $b.Margin    = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
    return $b
}

$btnToggle = New-Btn "  Start  " $green  $white 120
$btnReset  = New-Btn "  Reset  " $panelColor $muted 110
$btnQuit   = New-Btn "   Quit  " $panelColor $red   110

[void]$btnPanel.Controls.Add($btnToggle)
[void]$btnPanel.Controls.Add($btnReset)
[void]$btnPanel.Controls.Add($btnQuit)

# --- Stats panel ---
$statsPanel           = New-Object System.Windows.Forms.Panel
$statsPanel.Location  = New-Object System.Drawing.Point(12, 122)
$statsPanel.Size      = New-Object System.Drawing.Size(576, 78)
$statsPanel.BackColor = $panelColor
$statsPanel.Anchor    = [System.Windows.Forms.AnchorStyles]"Top,Left,Right"
$form.Controls.Add($statsPanel)

$statsTable             = New-Object System.Windows.Forms.TableLayoutPanel
$statsTable.Dock        = "Fill"
$statsTable.ColumnCount = 3
$statsTable.RowCount    = 2
$statsTable.BackColor   = $panelColor

foreach ($pct in @(33.33, 33.33, 33.34)) {
    $cs = New-Object System.Windows.Forms.ColumnStyle
    $cs.SizeType = [System.Windows.Forms.SizeType]::Percent
    $cs.Width    = $pct
    [void]$statsTable.ColumnStyles.Add($cs)
}

$rs1 = New-Object System.Windows.Forms.RowStyle
$rs1.SizeType = [System.Windows.Forms.SizeType]::Absolute
$rs1.Height   = 26
[void]$statsTable.RowStyles.Add($rs1)

$rs2 = New-Object System.Windows.Forms.RowStyle
$rs2.SizeType = [System.Windows.Forms.SizeType]::Percent
$rs2.Height   = 100
[void]$statsTable.RowStyles.Add($rs2)

[void]$statsPanel.Controls.Add($statsTable)

function New-StatCell($table, $col, $labelText, $init) {
    $lbl           = New-Object System.Windows.Forms.Label
    $lbl.Text      = $labelText
    $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
    $lbl.ForeColor = $muted
    $lbl.Dock      = "Fill"
    $lbl.Margin    = New-Object System.Windows.Forms.Padding(10, 6, 4, 0)
    $lbl.TextAlign = [System.Drawing.ContentAlignment]::BottomLeft
    [void]$table.Controls.Add($lbl, $col, 0)

    $val           = New-Object System.Windows.Forms.Label
    $val.Text      = $init
    $val.Font      = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
    $val.ForeColor = $textColor
    $val.Dock      = "Fill"
    $val.Margin    = New-Object System.Windows.Forms.Padding(10, 0, 4, 6)
    $val.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    [void]$table.Controls.Add($val, $col, 1)
    return $val
}

$lblIterCount = New-StatCell $statsTable 0 "Iterations" "0"
$lblUptime    = New-StatCell $statsTable 1 "Uptime"     "--:--:--"
$lblCountdown = New-StatCell $statsTable 2 "Next press" "--:--"

# --- SplitContainer: Log (left) + Leaderboard (right) ---
$sc = New-Object System.Windows.Forms.SplitContainer
$sc.Location         = New-Object System.Drawing.Point(12, 212)
$sc.Size             = New-Object System.Drawing.Size(576, 296)
$sc.Anchor           = [System.Windows.Forms.AnchorStyles]"Top,Left,Right,Bottom"
$sc.SplitterDistance = 356
$sc.BackColor        = $bgColor
$sc.Panel1.BackColor = $bgColor
$sc.Panel2.BackColor = $bgColor
$form.Controls.Add($sc)

function New-PanelSection($parent, $title) {
    $lbl           = New-Object System.Windows.Forms.Label
    $lbl.Text      = $title
    $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
    $lbl.ForeColor = $muted
    $lbl.Location  = New-Object System.Drawing.Point(2, 0)
    $lbl.AutoSize  = $true
    [void]$parent.Controls.Add($lbl)

    $rtb             = New-Object System.Windows.Forms.RichTextBox
    $rtb.Location    = New-Object System.Drawing.Point(0, 18)
    $rtb.Size        = New-Object System.Drawing.Size($parent.Width, ($parent.Height - 18))
    $rtb.BackColor   = $panelColor
    $rtb.ForeColor   = $textColor
    $rtb.Font        = New-Object System.Drawing.Font("Consolas", 9)
    $rtb.ReadOnly    = $true
    $rtb.BorderStyle = "None"
    $rtb.ScrollBars  = "Vertical"
    $rtb.Anchor      = [System.Windows.Forms.AnchorStyles]"Top,Left,Right,Bottom"
    [void]$parent.Controls.Add($rtb)
    return $rtb
}

$rtbLog      = New-PanelSection $sc.Panel1 "Log"
$rtbSessions = New-PanelSection $sc.Panel2 "Top Sessions"

# --- Helper functions ---
function Write-Log($text, $color) {
    $rtbLog.SelectionStart  = $rtbLog.TextLength
    $rtbLog.SelectionLength = 0
    $rtbLog.SelectionColor  = $color
    $rtbLog.AppendText("$text`n")
    $rtbLog.ScrollToCaret()
}

function Update-Leaderboard {
    $rtbSessions.Clear()
    if ($script:sessions.Count -eq 0) {
        $rtbSessions.SelectionColor = $muted
        $rtbSessions.AppendText("No completed sessions yet.")
        return
    }
    $rtbSessions.SelectionColor = $muted
    $rtbSessions.AppendText(" #   Duration    Presses`n")
    $rtbSessions.AppendText(("-" * 24) + "`n")
    $rank = 1
    foreach ($s in $script:sessions) {
        $h    = [int][math]::Floor($s.Duration.TotalHours)
        $dur  = "{0:D2}:{1:D2}:{2:D2}" -f $h, $s.Duration.Minutes, $s.Duration.Seconds
        $line = " {0,-3}  {1,-11} {2}" -f "$rank.", $dur, $s.Iterations
        $rtbSessions.SelectionColor = if ($rank -eq 1) { $gold } else { $textColor }
        $rtbSessions.AppendText("$line`n")
        $rank++
    }
}

function Save-CurrentSession {
    if ($null -ne $script:startTime -and $script:nbre -gt 0) {
        $entry = [PSCustomObject]@{
            Duration   = (Get-Date) - $script:startTime
            Iterations = $script:nbre
        }
        $script:sessions += $entry
        $script:sessions = @($script:sessions | Sort-Object -Property Duration -Descending | Select-Object -First 10)
        Update-Leaderboard
    }
}

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

function Start-Monitoring {
    $script:isRunning     = $true
    $script:startTime     = Get-Date
    $script:nextPressTime = $null
    $lblStatus.Text       = "* Active"
    $lblStatus.ForeColor  = $green
    $btnToggle.Text       = "  Stop   "
    $btnToggle.BackColor  = $orange
    $btnToggle.ForeColor  = $white
    Write-Log "--- Session started ---" $muted
    Invoke-Press
    $mainTimer.Start()
}

function Stop-Monitoring {
    $mainTimer.Stop()
    $script:isRunning    = $false
    $lblStatus.Text      = "* Inactive"
    $lblStatus.ForeColor = $red
    $btnToggle.Text      = "  Start  "
    $btnToggle.BackColor = $green
    $btnToggle.ForeColor = $white
    $lblCountdown.Text   = "--:--"
    Write-Log "--- Session stopped ---" $muted
    Save-CurrentSession
}

# --- Timers ---
$mainTimer          = New-Object System.Windows.Forms.Timer
$mainTimer.Interval = 120000
$mainTimer.Add_Tick({ Invoke-Press })

$uiTimer          = New-Object System.Windows.Forms.Timer
$uiTimer.Interval = 1000
$uiTimer.Add_Tick({
    if ($script:isRunning -and $null -ne $script:startTime) {
        $elapsed = (Get-Date) - $script:startTime
        $h = [int][math]::Floor($elapsed.TotalHours)
        $lblUptime.Text = "{0:D2}:{1:D2}:{2:D2}" -f $h, $elapsed.Minutes, $elapsed.Seconds
    }
    if ($script:isRunning -and $null -ne $script:nextPressTime) {
        $rem = $script:nextPressTime - (Get-Date)
        $lblCountdown.Text = if ($rem.TotalSeconds -gt 0) {
            "{0}:{1:D2}" -f $rem.Minutes, $rem.Seconds
        } else { "0:00" }
    }
})

# --- Button events ---
$btnToggle.Add_Click({
    if ($script:isRunning) { Stop-Monitoring } else { Start-Monitoring }
})

$btnReset.Add_Click({
    Save-CurrentSession
    $script:nbre = 0
    $script:startTime = if ($script:isRunning) { Get-Date } else { $null }
    $script:nextPressTime = $null
    $lblIterCount.Text = "0"
    $lblUptime.Text    = if ($script:isRunning) { "00:00:00" } else { "--:--:--" }
    $lblCountdown.Text = if ($script:isRunning) { "2:00" } else { "--:--" }
    $rtbLog.Clear()
    Write-Log "--- Stats reset ---" $muted
})

$btnQuit.Add_Click({
    if ($script:isRunning) { Stop-Monitoring }
    $form.Close()
})

# --- Start ---
$form.Add_Shown({
    Update-Leaderboard
    $uiTimer.Start()
})

$form.Add_FormClosing({
    $mainTimer.Stop()
    $uiTimer.Stop()
})

[System.Windows.Forms.Application]::Run($form)
