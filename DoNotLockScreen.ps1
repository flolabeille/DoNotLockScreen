Clear-Host

Write-Host "Running..." -ForegroundColor Magenta
$nbre = 0

# Création de l'objet WScript.Shell
$WShell = New-Object -com "Wscript.shell"

While ($true) {
    $nbre = $nbre+1
    $date = Get-Date -Format "dd-MM-yyyy hh:mm:ss"

    try {
        $WShell.SendKeys("{PRTSC}")
        Start-Sleep -Milliseconds 100
        Write-Host "[$nbre] : $date" -ForegroundColor Green
    }
    catch {
        Write-Host "[$nbre] : $date" -ForegroundColor Red
    }

    Start-Sleep -Seconds 120
}