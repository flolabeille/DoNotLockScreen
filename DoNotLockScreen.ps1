Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
#  STATE
# ============================================================
$script:nbre          = 0
$script:isRunning     = $false
$script:startTime     = $null
$script:nextPressTime = $null
$script:sessions      = @()
$script:logEntries    = @()   # {Text, ColorKey} buffer for theme re-render
$script:mutedLabels   = @()   # labels whose color tracks the theme muted color
$script:isDark        = $true
$WShell               = New-Object -com "Wscript.Shell"

# ============================================================
#  FIXED COLORS  (same on both themes)
# ============================================================
$accent = [System.Drawing.Color]::FromArgb(167, 139, 250)
$green  = [System.Drawing.Color]::FromArgb( 52, 211, 153)
$red    = [System.Drawing.Color]::FromArgb(248, 113, 113)
$orange = [System.Drawing.Color]::FromArgb(251, 146,  60)
$gold   = [System.Drawing.Color]::FromArgb(250, 204,  21)
$white  = [System.Drawing.Color]::White

# ============================================================
#  THEMES
# ============================================================
$darkTheme = @{
    bg    = [System.Drawing.Color]::FromArgb( 15,  15,  15)
    panel = [System.Drawing.Color]::FromArgb( 28,  28,  30)
    text  = [System.Drawing.Color]::FromArgb(229, 229, 231)
    muted = [System.Drawing.Color]::FromArgb(113, 113, 122)
}
$lightTheme = @{
    bg    = [System.Drawing.Color]::FromArgb(245, 245, 250)
    panel = [System.Drawing.Color]::FromArgb(225, 225, 238)
    text  = [System.Drawing.Color]::FromArgb( 20,  20,  30)
    muted = [System.Drawing.Color]::FromArgb(105, 105, 120)
}
$script:th = $darkTheme

# ============================================================
#  ICON  (open padlock drawn with GDI+)
# ============================================================
function New-AppIcon {
    $bmp = New-Object System.Drawing.Bitmap(32, 32)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    # Purple background
    $g.Clear([System.Drawing.Color]::FromArgb(109, 40, 217))

    $wBrush = New-Object System.Drawing.SolidBrush($white)
    $hBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(109, 40, 217))
    $pen    = New-Object System.Drawing.Pen($white, 3.0)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round

    # Lock body
    $g.FillRectangle($wBrush, 6, 17, 20, 12)

    # Keyhole (circle + stem)
    $g.FillEllipse($hBrush, 13, 19, 6, 6)
    $g.FillRectangle($hBrush, 14, 24, 4, 4)

    # Shackle – left arm connects to body, right arm is raised (open)
    $g.DrawLine($pen, 10, 18, 10, 12)          # left arm
    $g.DrawArc($pen, 10, 6, 12, 12, 180, 180)  # top arc (10,12) -> (22,12)
    $g.DrawLine($pen, 22, 12, 22,  7)           # right arm (raised, open)

    $g.Dispose(); $wBrush.Dispose(); $hBrush.Dispose(); $pen.Dispose()

    $hIcon = $bmp.GetHicon()
    $bmp.Dispose()
    return [System.Drawing.Icon]::FromHandle($hIcon)
}

# ============================================================
#  FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text            = "DoNotLockScreen"
$form.ClientSize      = New-Object System.Drawing.Size(620, 530)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MinimumSize     = New-Object System.Drawing.Size(520, 430)
$form.BackColor       = $script:th.bg
$form.Icon            = New-AppIcon

# ============================================================
#  HEADER
# ============================================================
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

# ============================================================
#  BUTTON PANEL
# ============================================================
$btnPanel              = New-Object System.Windows.Forms.FlowLayoutPanel
$btnPanel.Location     = New-Object System.Drawing.Point(12, 68)
$btnPanel.Size         = New-Object System.Drawing.Size(596, 46)
$btnPanel.BackColor    = $script:th.bg
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

$btnToggle = New-Btn "  Start  "   $green             $white            120
$btnReset  = New-Btn "  Reset  "   $script:th.panel   $script:th.muted  110
$btnTheme  = New-Btn " Mode clair" $script:th.panel   $script:th.muted  120
$btnQuit   = New-Btn "   Quit   "  $script:th.panel   $red              110

[void]$btnPanel.Controls.Add($btnToggle)
[void]$btnPanel.Controls.Add($btnReset)
[void]$btnPanel.Controls.Add($btnTheme)
[void]$btnPanel.Controls.Add($btnQuit)

# ============================================================
#  STATS PANEL
# ============================================================
$statsPanel           = New-Object System.Windows.Forms.Panel
$statsPanel.Location  = New-Object System.Drawing.Point(12, 122)
$statsPanel.Size      = New-Object System.Drawing.Size(596, 78)
$statsPanel.BackColor = $script:th.panel
$statsPanel.Anchor    = [System.Windows.Forms.AnchorStyles]"Top,Left,Right"
$form.Controls.Add($statsPanel)

$statsTable             = New-Object System.Windows.Forms.TableLayoutPanel
$statsTable.Dock        = "Fill"
$statsTable.ColumnCount = 3
$statsTable.RowCount    = 2
$statsTable.BackColor   = $script:th.panel

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
    $lbl.ForeColor = $script:th.muted
    $lbl.Dock      = "Fill"
    $lbl.Margin    = New-Object System.Windows.Forms.Padding(10, 6, 4, 0)
    $lbl.TextAlign = [System.Drawing.ContentAlignment]::BottomLeft
    [void]$table.Controls.Add($lbl, $col, 0)
    $script:mutedLabels += $lbl

    $val           = New-Object System.Windows.Forms.Label
    $val.Text      = $init
    $val.Font      = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
    $val.ForeColor = $script:th.text
    $val.Dock      = "Fill"
    $val.Margin    = New-Object System.Windows.Forms.Padding(10, 0, 4, 6)
    $val.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    [void]$table.Controls.Add($val, $col, 1)
    return $val
}

$lblIterCount = New-StatCell $statsTable 0 "Iterations" "0"
$lblUptime    = New-StatCell $statsTable 1 "Uptime"     "--:--:--"
$lblCountdown = New-StatCell $statsTable 2 "Next press" "--:--"

# ============================================================
#  SPLIT CONTAINER  (Log | Top Sessions)
# ============================================================
$sc = New-Object System.Windows.Forms.SplitContainer
$sc.Location         = New-Object System.Drawing.Point(12, 212)
$sc.Size             = New-Object System.Drawing.Size(596, 306)
$sc.Anchor           = [System.Windows.Forms.AnchorStyles]"Top,Left,Right,Bottom"
$sc.SplitterDistance = 370
$sc.BackColor        = $script:th.bg
$sc.Panel1.BackColor = $script:th.bg
$sc.Panel2.BackColor = $script:th.bg
$form.Controls.Add($sc)

function New-PanelSection($parent, $title) {
    $lbl           = New-Object System.Windows.Forms.Label
    $lbl.Text      = $title
    $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
    $lbl.ForeColor = $script:th.muted
    $lbl.Location  = New-Object System.Drawing.Point(2, 0)
    $lbl.AutoSize  = $true
    [void]$parent.Controls.Add($lbl)
    $script:mutedLabels += $lbl

    $rtb             = New-Object System.Windows.Forms.RichTextBox
    $rtb.Location    = New-Object System.Drawing.Point(0, 18)
    $rtb.Size        = New-Object System.Drawing.Size($parent.Width, ($parent.Height - 18))
    $rtb.BackColor   = $script:th.panel
    $rtb.ForeColor   = $script:th.text
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

# ============================================================
#  LOG  (buffered for theme re-render)
# ============================================================
function Append-LogEntry($entry) {
    $color = if     ($entry.ColorKey -eq 'green') { $green }
             elseif ($entry.ColorKey -eq 'red')   { $red   }
             else                                  { $script:th.muted }
    $rtbLog.SelectionStart  = $rtbLog.TextLength
    $rtbLog.SelectionLength = 0
    $rtbLog.SelectionColor  = $color
    $rtbLog.AppendText("$($entry.Text)`n")
    $rtbLog.ScrollToCaret()
}

function Write-Log($text, $colorKey) {
    $entry = [PSCustomObject]@{ Text = $text; ColorKey = $colorKey }
    $script:logEntries += $entry
    Append-LogEntry $entry
}

function Refresh-Log {
    $rtbLog.Clear()
    foreach ($e in $script:logEntries) { Append-LogEntry $e }
}

# ============================================================
#  LEADERBOARD
# ============================================================
function Update-Leaderboard {
    $rtbSessions.Clear()
    if ($script:sessions.Count -eq 0) {
        $rtbSessions.SelectionColor = $script:th.muted
        $rtbSessions.AppendText("No completed sessions yet.")
        return
    }
    $rtbSessions.SelectionColor = $script:th.muted
    $rtbSessions.AppendText(" #   Duration    Presses`n")
    $rtbSessions.AppendText(("-" * 24) + "`n")
    $rank = 1
    foreach ($s in $script:sessions) {
        $h    = [int][math]::Floor($s.Duration.TotalHours)
        $dur  = "{0:D2}:{1:D2}:{2:D2}" -f $h, $s.Duration.Minutes, $s.Duration.Seconds
        $line = " {0,-3}  {1,-11} {2}" -f "$rank.", $dur, $s.Iterations
        $rtbSessions.SelectionColor = if ($rank -eq 1) { $gold } else { $script:th.text }
        $rtbSessions.AppendText("$line`n")
        $rank++
    }
}

# ============================================================
#  THEME SWITCH
# ============================================================
function Apply-Theme {
    $t = $script:th

    $form.BackColor        = $t.bg
    $btnPanel.BackColor    = $t.bg
    $statsPanel.BackColor  = $t.panel
    $statsTable.BackColor  = $t.panel
    $sc.BackColor          = $t.bg
    $sc.Panel1.BackColor   = $t.bg
    $sc.Panel2.BackColor   = $t.bg
    $rtbLog.BackColor      = $t.panel
    $rtbLog.ForeColor      = $t.text
    $rtbSessions.BackColor = $t.panel
    $rtbSessions.ForeColor = $t.text

    $lblIterCount.ForeColor = $t.text
    $lblUptime.ForeColor    = $t.text
    $lblCountdown.ForeColor = $t.text

    foreach ($lbl in $script:mutedLabels) { $lbl.ForeColor = $t.muted }

    $btnReset.BackColor  = $t.panel
    $btnReset.ForeColor  = $t.muted
    $btnQuit.BackColor   = $t.panel
    $btnTheme.BackColor  = $t.panel
    $btnTheme.ForeColor  = $t.muted
    $btnTheme.Text       = if ($script:isDark) { " Mode clair" } else { " Mode sombre" }

    Refresh-Log
    Update-Leaderboard
}

# ============================================================
#  SESSION LOGIC
# ============================================================
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
        Write-Log "[$($script:nbre)] $date" 'green'
    } catch {
        Write-Log "[$($script:nbre)] $date  --  Error" 'red'
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
    Write-Log "--- Session started ---" 'muted'
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
    Write-Log "--- Session stopped ---" 'muted'
    Save-CurrentSession
}

# ============================================================
#  TIMERS
# ============================================================
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

# ============================================================
#  BUTTON EVENTS
# ============================================================
$btnToggle.Add_Click({
    if ($script:isRunning) { Stop-Monitoring } else { Start-Monitoring }
})

$btnReset.Add_Click({
    Save-CurrentSession
    $script:nbre          = 0
    $script:logEntries    = @()
    $script:startTime     = if ($script:isRunning) { Get-Date } else { $null }
    $script:nextPressTime = $null
    $lblIterCount.Text    = "0"
    $lblUptime.Text       = if ($script:isRunning) { "00:00:00" } else { "--:--:--" }
    $lblCountdown.Text    = if ($script:isRunning) { "2:00"     } else { "--:--"    }
    $rtbLog.Clear()
    Write-Log "--- Stats reset ---" 'muted'
})

$btnTheme.Add_Click({
    $script:isDark = -not $script:isDark
    $script:th     = if ($script:isDark) { $darkTheme } else { $lightTheme }
    Apply-Theme
})

$btnQuit.Add_Click({
    if ($script:isRunning) { Stop-Monitoring }
    $form.Close()
})

# ============================================================
#  LAUNCH
# ============================================================
$form.Add_Shown({
    Update-Leaderboard
    $uiTimer.Start()
})

$form.Add_FormClosing({
    $mainTimer.Stop()
    $uiTimer.Stop()
})

[System.Windows.Forms.Application]::Run($form)
