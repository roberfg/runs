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

if (-not (Test-Path $dotfiles))
{
    Write-Host ">>> Clonando dotfiles..." -ForegroundColor Cyan
    git clone https://github.com/roberfu/dotfiles.git $dotfiles
    if ($LASTEXITCODE -ne 0)
    { exit 1
    }
}

$wingetPkgs = @(
    @{ Name = "Chromium"; Id = "Hibbiki.Chromium" }
    @{ Name = "Alacritty"; Id = "Alacritty.Alacritty" }
    @{ Name = "Neovim"; Id = "Neovim.Neovim" }
    @{ Name = "VSCodium"; Id = "VSCodium.VSCodium" }
    @{ Name = "Steam"; Id = "Valve.Steam" }
    @{ Name = "PowerShell"; Id = "Microsoft.PowerShell" }
    @{ Name = "qBittorrent"; Id = "qBittorrent.qBittorrent" }
    @{ Name = "ffmpeg"; Id = "Gyan.FFmpeg" }
    @{ Name = "Spotify"; Id = "Spotify.Spotify" }
    @{ Name = "Node.js LTS"; Id = "OpenJS.NodeJS.LTS" }
    @{ Name = "Yarn"; Id = "Yarn.Yarn" }
    @{ Name = "OpenJDK 25"; Id = "EclipseAdoptium.Temurin.25.JDK" }
    @{ Name = "Maven"; Id = "Apache.Maven" }
    @{ Name = "Spring Tools 4"; Id = "vmware.spring-tools-4-for-eclipse" }
    @{ Name = "Podman"; Id = "RedHat.Podman" }
    @{ Name = "Revo Uninstaller"; Id = "VSRevo.RevoUninstaller" }
    @{ Name = "7-Zip"; Id = "7zip.7zip" }
    @{ Name = "Bruno"; Id = "Bruno.Bruno" }
    @{ Name = "yt-dlp"; Id = "yt-dlp.yt-dlp" }
    @{ Name = "Notepad++"; Id = "Notepad++.Notepad++" }
    @{ Name = "GNU Make"; Id = "GnuWin32.Make" }
    @{ Name = "MinGW-w64 GCC"; Id = "niXman.MinGW-w64-GCC" }
)

Write-Host ">>> Instalando paquetes con winget..." -ForegroundColor Cyan
foreach ($pkg in $wingetPkgs)
{
    $installed = winget list --exact --id $pkg.Id --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0)
    {
        Write-Host "  ya instalado: $($pkg.Name)" -ForegroundColor DarkYellow
    } else
    {
        Write-Host "  instalando: $($pkg.Name)..." -ForegroundColor Cyan
        winget install --exact --id $pkg.Id --silent --accept-package-agreements --accept-source-agreements
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
    npm install -g opencode-ai@latest
    if ($LASTEXITCODE -ne 0)
    {
        Write-Warning "npm install -g opencode-ai fallo (exit $LASTEXITCODE)"
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

Write-Host "`nPresione Enter para cerrar..." -ForegroundColor Green
Read-Host
