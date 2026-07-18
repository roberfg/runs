$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$devMode = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1

if (-not $isAdmin -and -not $devMode)
{
    Write-Host ">>> Elevando a Administrador..." -ForegroundColor Yellow
    $shell = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
    Start-Process $shell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$dotfiles = Join-Path $PSScriptRoot "..\dotfiles"
$homeDir = $env:USERPROFILE

if (Test-Path $dotfiles)
{
    if (Test-Path (Join-Path $dotfiles ".git"))
    {
        Write-Host ">>> Actualizando dotfiles..." -ForegroundColor Cyan
        git -C $dotfiles pull --ff-only 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0)
        {
            Write-Warning "git pull fallo (puede haber cambios locales); continuando con la version actual"
        }
    } else
    {
        Write-Host ">>> $dotfiles existe pero no es un repo git. Eliminando para re-clonar." -ForegroundColor Yellow
        Remove-Item -LiteralPath $dotfiles -Recurse -Force
    }
}
if (-not (Test-Path $dotfiles))
{
    Write-Host ">>> Clonando dotfiles..." -ForegroundColor Cyan
    git clone https://github.com/roberfu/dotfiles.git $dotfiles
    if ($LASTEXITCODE -ne 0)
    { exit 1
    }
}

$wingetPkgs = @(
    # Sistema / fuentes
    @{ Name = "JetBrainsMono Nerd Font"; Id = "DEVCOM.JetBrainsMonoNerdFont" }
    @{ Name = "VC++ Redist 2015+ x64"; Id = "Microsoft.VCRedist.2015+.x64" }
    @{ Name = "7-Zip"; Id = "7zip.7zip" }
    @{ Name = "Make"; Id = "GnuWin32.Make" }
    # Runtime
    @{ Name = "PowerShell"; Id = "Microsoft.PowerShell" }
    @{ Name = "Node.js LTS"; Id = "OpenJS.NodeJS.LTS" }
    @{ Name = "Yarn"; Id = "Yarn.Yarn" }
    @{ Name = "OpenJDK 25"; Id = "EclipseAdoptium.Temurin.25.JDK" }
    # Editores / dev
    @{ Name = "Neovim"; Id = "Neovim.Neovim" }
    @{ Name = "VSCodium"; Id = "VSCodium.VSCodium" }
    @{ Name = "Zed"; Id = "ZedIndustries.Zed" }
    @{ Name = "Alacritty"; Id = "Alacritty.Alacritty" }
    # Apps
    @{ Name = "Brave Browser"; Id = "Brave.Brave" }
    @{ Name = "qBittorrent"; Id = "qBittorrent.qBittorrent" }
    @{ Name = "ffmpeg"; Id = "Gyan.FFmpeg" }
    @{ Name = "Spotify"; Id = "Spotify.Spotify" }
    @{ Name = "Steam"; Id = "Valve.Steam" }
    @{ Name = "Podman"; Id = "RedHat.Podman" }
    @{ Name = "Bruno"; Id = "Bruno.Bruno" }
    @{ Name = "Notepad++"; Id = "Notepad++.Notepad++" }
    @{ Name = "Revo Uninstaller"; Id = "RevoUninstaller.RevoUninstaller" }
)

$installResults = @()
Write-Host ">>> Instalando paquetes con winget..." -ForegroundColor Cyan
foreach ($pkg in $wingetPkgs)
{
    $null = winget list --exact --id $pkg.Id --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0)
    {
        Write-Host "  ya instalado: $($pkg.Name)" -ForegroundColor DarkYellow
        $installResults += @{ Name = $pkg.Name; Status = "ya-instalado" }
    } else
    {
        Write-Host "  instalando: $($pkg.Name)..." -ForegroundColor Cyan
        winget install --exact --id $pkg.Id --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0)
        {
            $installResults += @{ Name = $pkg.Name; Status = "instalado" }
        } else
        {
            Write-Warning "    fallo al instalar $($pkg.Name)"
            $installResults += @{ Name = $pkg.Name; Status = "fallo" }
        }
    }
}

function Update-PathFromRegistry {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Host ">>> Instalando opencode via npm..." -ForegroundColor Cyan
$nodeVer = node --version 2>$null
if (-not $nodeVer)
{
    Write-Host "  Node.js no detectado en la sesion, refrescando PATH desde registro..." -ForegroundColor Yellow
    Update-PathFromRegistry
    $nodeVer = node --version 2>$null
}
if ($nodeVer)
{
    Write-Host "  Node $nodeVer detectado" -ForegroundColor DarkYellow
    $opencodeVer = opencode --version 2>$null
    if ($opencodeVer)
    {
        Write-Host "  opencode $opencodeVer ya instalado; saltando npm install" -ForegroundColor DarkYellow
    } else
    {
        npm install -g opencode-ai@latest
        if ($LASTEXITCODE -ne 0)
        {
            Write-Warning "npm install -g opencode-ai fallo (exit $LASTEXITCODE)"
        }
        Write-Host "  Refrescando PATH tras npm install..." -ForegroundColor DarkYellow
        Update-PathFromRegistry
    }
} else
{
    Write-Warning "Node.js no encontrado tras refrescar PATH; saltando opencode"
}

$symlinks = @(
    @{ src = Join-Path $dotfiles ".gitconfig"; dst = Join-Path $homeDir ".gitconfig" }
    @{ src = Join-Path $dotfiles ".gitattributes"; dst = Join-Path $homeDir ".gitattributes" }
    @{ src = Join-Path $dotfiles ".config\VSCodium\User\settings.json"; dst = Join-Path $homeDir "AppData\Roaming\VSCodium\User\settings.json" }
    @{ src = Join-Path $dotfiles ".config\nvim"; dst = Join-Path $env:LOCALAPPDATA "nvim" }
    @{ src = Join-Path $dotfiles ".alacritty.toml"; dst = Join-Path $env:APPDATA "alacritty\alacritty.toml" }
    @{ src = Join-Path $dotfiles ".config\opencode\opencode.jsonc"; dst = Join-Path $homeDir ".config\opencode\opencode.jsonc" }
    @{ src = Join-Path $dotfiles ".config\opencode\tui.json"; dst = Join-Path $homeDir ".config\opencode\tui.json" }
    @{ src = Join-Path $dotfiles ".config\opencode\AGENTS.md"; dst = Join-Path $homeDir ".config\opencode\AGENTS.md" }
    @{ src = Join-Path $dotfiles ".config\opencode\skills"; dst = Join-Path $homeDir ".config\opencode\skills" }
    @{ src = Join-Path $dotfiles ".config\zed"; dst = Join-Path $env:APPDATA "Zed" }
)

foreach ($item in $symlinks)
{
    if (-not (Test-Path $item.src))
    {
        Write-Warning "No encontrado: $($item.src)"
        continue
    }
    $dstDir = Split-Path $item.dst -Parent
    if (-not (Test-Path $dstDir))
    { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

    if (Test-Path $item.dst)
    {
        $isSymlink = (Get-Item $item.dst).Attributes -band [System.IO.FileAttributes]::ReparsePoint
        if ($isSymlink)
        {
            Remove-Item -LiteralPath $item.dst -Force
            Write-Host "Eliminado symlink existente: $($item.dst)" -ForegroundColor DarkYellow
        } else
        {
            $backup = "$($item.dst).bak"
            Move-Item -LiteralPath $item.dst -Destination $backup -Force
            Write-Host "Respaldado: $($item.dst) -> $backup" -ForegroundColor DarkYellow
        }
    }
    New-Item -ItemType SymbolicLink -Path $item.dst -Target $item.src -Force
    Write-Host "Symlink: $($item.dst) <- $($item.src)"
}

Write-Host ""
Write-Host ">>> Resumen winget" -ForegroundColor Cyan
$okCount = ($installResults | Where-Object { $_.Status -eq "instalado" }).Count
$skippedCount = ($installResults | Where-Object { $_.Status -eq "ya-instalado" }).Count
$failed = $installResults | Where-Object { $_.Status -eq "fallo" }
$failedCount = $failed.Count
Write-Host "  Instalados en esta corrida: $okCount" -ForegroundColor Green
Write-Host "  Ya estaban:                $skippedCount" -ForegroundColor DarkYellow
if ($failedCount -gt 0)
{
    Write-Host "  Fallos:                    $failedCount" -ForegroundColor Red
    foreach ($f in $failed)
    {
        Write-Host "    - $($f.Name)" -ForegroundColor Red
    }
} else
{
    Write-Host "  Fallos:                    0" -ForegroundColor Green
}

Write-Host ""
Write-Host ">>> ACCION MANUAL REQUERIDA: Maven" -ForegroundColor Yellow
Write-Host "  Maven no esta disponible en winget. Para instalarlo:" -ForegroundColor Yellow
Write-Host "    1. Descarga apache-maven-3.9.x-bin.zip desde https://maven.apache.org/download.cgi"
Write-Host "    2. Extrae en C:\Tools\apache-maven-3.9.x\"
Write-Host "    3. Variable de sistema MAVEN_HOME = C:\Tools\apache-maven-3.9.x"
Write-Host "    4. Anade %MAVEN_HOME%\bin al PATH del sistema"
Write-Host "    5. Abre una nueva terminal y verifica con: mvn --version"
Write-Host ""
Write-Host "Presione Enter para cerrar..." -ForegroundColor Green
Read-Host
