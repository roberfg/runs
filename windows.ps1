$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$devMode = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1

if (-not $isAdmin -and -not $devMode)
{
    Write-Host ">>> Elevando a Administrador..." -ForegroundColor Yellow
    Start-Process pwsh.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$dotfiles = Join-Path $PSScriptRoot "..\dotfiles"
$homeDir = "C:\Users\$env:USERNAME"

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
    @{ Name = "Git"; Id = "Git.Git" }
    @{ Name = "Alacritty"; Id = "Alacritty.Alacritty" }
    @{ Name = "Neovim"; Id = "Neovim.Neovim" }
    @{ Name = "Oh My Posh"; Id = "JanDeDobbeleer.OhMyPosh" }
    @{ Name = "VSCodium"; Id = "VSCodium.VSCodium" }
    @{ Name = "Zed"; Id = "ZedIndustries.Zed" }
    @{ Name = "Steam"; Id = "Valve.Steam" }
    @{ Name = "PowerShell"; Id = "Microsoft.PowerShell" }
    @{ Name = "VCRedist.2015"; Id = "Microsoft.VCRedist.2015+.x64" }
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

Write-Host ">>> Instalando Scoop..." -ForegroundColor Cyan
if (-not (Get-Command scoop -ErrorAction SilentlyContinue))
{
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    irm get.scoop.sh | iex
}

Write-Host ">>> Agregando buckets de Scoop..." -ForegroundColor Cyan
scoop bucket add java
scoop bucket add extras

Write-Host ">>> Instalando paquetes con Scoop..." -ForegroundColor Cyan
scoop install extras/qbittorrent extras/mpv main/ffmpeg extras/spotify main/yarn main/opencode main/make main/gcc main/mingw main/nodejs-lts java/openjdk25 main/maven extras/sts main/podman extras/revouninstaller main/7zip extras/bruno

$symlinks = @(
    @{ src = Join-Path $dotfiles ".gitconfig"; dst = Join-Path $homeDir ".gitconfig" }
    @{ src = Join-Path $dotfiles ".gitattributes"; dst = Join-Path $homeDir ".gitattributes" }
    @{ src = Join-Path $dotfiles ".config\oh-my-posh\avit.omp.json"; dst = Join-Path $homeDir ".config\oh-my-posh\avit.omp.json" }
    @{ src = Join-Path $dotfiles ".config\VSCodium\User\settings.json"; dst = Join-Path $homeDir "AppData\Roaming\VSCodium\User\settings.json" }
    @{ src = Join-Path $dotfiles ".config\nvim"; dst = Join-Path $env:LOCALAPPDATA "nvim" }
    @{ src = Join-Path $dotfiles ".config\zed\settings.json"; dst = Join-Path $homeDir "AppData\Roaming\Zed\settings.json" }
    @{ src = Join-Path $dotfiles ".alacritty.toml"; dst = Join-Path $env:APPDATA "alacritty\alacritty.toml" }
    @{ src = Join-Path $dotfiles ".config\opencode\opencode.jsonc"; dst = Join-Path $homeDir ".config\opencode\opencode.jsonc" }
    @{ src = Join-Path $dotfiles ".config\opencode\tui.json"; dst = Join-Path $homeDir ".config\opencode\tui.json" }
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
