# runs

Scripts de automatización para configurar mi entorno de trabajo en diferentes sistemas operativos.

## Descripción

Este proyecto contiene scripts para instalar y configurar herramientas de desarrollo, aplicaciones de productividad y utilidades del sistema de forma automática.

## Scripts disponibles

| Script | Sistema operativo |
|--------|-------------------|
| `windows.ps1` | Windows |
| `wsl-ubuntu.sh` | WSL con la distro Ubuntu |
| `bazzite.sh` | Bazzite |
| `cachyos.sh` | CachyOS |
| `nobara.sh` | Nobara |

## Uso

### Windows

```powershell
Set-ExecutionPolicy Unrestricted -Scope Process
.\windows.ps1
```

### Linux / WSL

```bash
# WSL Ubuntu
bash wsl-ubuntu.sh

# Bazzite
bash bazzite.sh

# CachyOS
bash cachyos.sh

# Nobara
bash nobara.sh
```

## Requisitos

- **Windows**: Winget instalado
- **Linux**: Bash y permisos de sudo

## TODO

- [ ] Implementar lógica de instalación en scripts `.sh` vacíos (bazzite, cachyos, nobara, wsl-ubuntu)
- [ ] Agregar detección automática del SO para script unificado (`install.sh`)
- [ ] Mejorar manejo de errores en `windows.ps1` y futuros scripts
- [ ] Soportar más entornos Linux (pop-os, nixos, opensuse)
- [ ] Agregar logging y verbosidad configurable (flag `--verbose`)
- [ ] Crear script de limpieza/desinstalación (`clean.ps1` / `clean.sh`)
- [ ] Agregar flag `--dry-run` para simular cambios sin aplicarlos
- [ ] Agregar flag `--skip-dotfiles` para omitir symlinks de dotfiles
- [ ] Documentar variables de entorno y configuración externa
- [ ] Soporte para dotfiles privados (repo configurable vía env var)
- [ ] Tests automatizados (Pester para PowerShell, bats para bash)
