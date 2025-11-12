# Script pour télécharger et installer les DLLs pyzbar manquantes
# Utilise les binaires officiels de pyzbar pour Windows

param(
    [switch]$NoWait = $false  # Si true, ne pas attendre (pause) à la fin
)

$ErrorActionPreference = "Stop"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Installation des DLLs pyzbar pour Windows  " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Trouver le chemin de pyzbar dans l'environnement Python
Write-Host "Recherche du dossier pyzbar..." -ForegroundColor Yellow

$pythonCode = @"
import sys
from pathlib import Path
for path_str in sys.path:
    potential_path = Path(path_str) / 'pyzbar'
    if potential_path.exists():
        print(str(potential_path))
        sys.exit(0)
sys.exit(1)
"@

$pyzbarPath = python -c $pythonCode 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($pyzbarPath)) {
    Write-Host "ERREUR: Dossier pyzbar introuvable!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Assurez-vous que pyzbar est installé:" -ForegroundColor Yellow
    Write-Host "  pip install pyzbar" -ForegroundColor White
    Write-Host ""
    pause
    exit 1
}

Write-Host "✓ Pyzbar trouvé: $pyzbarPath" -ForegroundColor Green
Write-Host ""

# Vérifier si les DLLs sont déjà présentes
$libIconvPath = Join-Path $pyzbarPath "libiconv.dll"
$libZbarPath = Join-Path $pyzbarPath "libzbar-64.dll"

$needDownload = $false
if (-not (Test-Path $libIconvPath)) {
    Write-Host "✗ libiconv.dll manquante" -ForegroundColor Red
    $needDownload = $true
} else {
    Write-Host "✓ libiconv.dll présente" -ForegroundColor Green
}

if (-not (Test-Path $libZbarPath)) {
    Write-Host "✗ libzbar-64.dll manquante" -ForegroundColor Red
    $needDownload = $true
} else {
    Write-Host "✓ libzbar-64.dll présente" -ForegroundColor Green
}

Write-Host ""

if (-not $needDownload) {
    Write-Host "✓ Toutes les DLLs sont déjà présentes!" -ForegroundColor Green
    Write-Host ""
    if (-not $NoWait) {
        pause
    }
    exit 0
}

Write-Host "Téléchargement des DLLs manquantes..." -ForegroundColor Yellow
Write-Host ""

# URLs des DLLs (depuis le repo officiel pyzbar)
$libIconvUrl = "https://raw.githubusercontent.com/NaturalHistoryMuseum/pyzbar/master/pyzbar/libiconv.dll"
$libZbarUrl = "https://raw.githubusercontent.com/NaturalHistoryMuseum/pyzbar/master/pyzbar/libzbar-64.dll"

try {
    # Télécharger libiconv.dll si manquante
    if (-not (Test-Path $libIconvPath)) {
        Write-Host "Téléchargement de libiconv.dll..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $libIconvUrl -OutFile $libIconvPath -UseBasicParsing
        Write-Host "✓ libiconv.dll téléchargée" -ForegroundColor Green
    }

    # Télécharger libzbar-64.dll si manquante
    if (-not (Test-Path $libZbarPath)) {
        Write-Host "Téléchargement de libzbar-64.dll..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $libZbarUrl -OutFile $libZbarPath -UseBasicParsing
        Write-Host "✓ libzbar-64.dll téléchargée" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host "  Installation réussie! ✓                    " -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Les DLLs pyzbar sont maintenant installées dans:" -ForegroundColor White
    Write-Host "  $pyzbarPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Vous pouvez maintenant relancer le build de l'exécutable." -ForegroundColor Yellow

} catch {
    Write-Host ""
    Write-Host "ERREUR lors du téléchargement: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Solution alternative:" -ForegroundColor Yellow
    Write-Host "  1. Téléchargez manuellement les DLLs depuis:" -ForegroundColor White
    Write-Host "     https://github.com/NaturalHistoryMuseum/pyzbar" -ForegroundColor Gray
    Write-Host "  2. Placez-les dans: $pyzbarPath" -ForegroundColor White
    Write-Host ""
    if (-not $NoWait) {
        pause
    }
    exit 1
}

Write-Host ""
if (-not $NoWait) {
    pause
}
