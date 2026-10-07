# Investigación: Dependencias de compilación de Clavis y soporte de M3Shapes en gracie

Investigación realizada para resolver el ticket [#9](https://github.com/robert-flo/quickshell/issues/9) de Wayfinder.

## 1. Inventario actual en gracie (Arch Linux)

| Paquete | Rol | Estado actual | Origen |
| :--- | :--- | :--- | :--- |
| `pkgconf` | Descubrimiento pkg-config | Instalado (3.0.7) | Arch `core` |
| `qt6-base` | Qt Core, GUI, DBus, Network | Instalado (6.12.0) | Arch `extra` |
| `qt6-declarative` | QML y Qt Quick | Instalado (6.12.0) | Arch `extra` |
| `qt6-wayland` | Cliente Wayland | Instalado (6.12.0) | Arch `extra` |
| `qt6-shadertools` | Compilador de shaders | Instalado (6.12.0) | Arch `extra` |
| `pipewire` | Captura de audio | Instalado (1.6.9) | Arch `extra` |
| `systemd-libs` | Headers de libudev | Instalado (262) | Arch `core` |
| `libxkbcommon` | Manejo de atajos | Instalado (1.13.2) | Arch `extra` |
| `quickshell` | Runtime de Quickshell | Instalado (0.3.1) | Arch `extra` |
| `niri` | Compositor Wayland | Instalado (26.04) | Arch `extra` |
| `cmake` | Configuración C++ | **Falta** | Arch `extra` |
| `ninja` | Generador de compilación | **Falta** | Arch `extra` |
| `qt6-tools` | LinguistTools (`lrelease`, etc.) | **Falta** | Arch `extra` |
| `qtkeychain-qt6` | Almacenamiento seguro | **Falta** | Arch `extra` |
| `libcava` | Librería Cava (audio visualizer) | **Falta** | AUR (`aur/libcava`) |
| `qt6-m3shapes-git` | Módulo QML M3Shapes | **Falta** | AUR (`aur/qt6-m3shapes-git`) |

## 2. Clasificación: Barra vs Shell completo

1. **Compilación de la barra (`Modules/Bar`):**
   - La barra únicamente importa el plugin nativo `Clavis.Niri`.
   - `Clavis.Niri` solo depende de `ClavisNiriCore`, `Qt6Core`, `Qt6Gui`, `Qt6Qml`, `Qt6Network`.
   - La barra **no** utiliza `libcava` ni `M3Shapes`.
   - Sin embargo, el `core/CMakeLists.txt` actual configura todos los módulos a la vez. Para compilar `core` tal como está estructurado hoy, se necesita resolver `libcava`.

2. **Rol de `qt6-m3shapes-git`:**
   - Es una dependencia externa de **runtime** para QML. No se compila con CMake.
   - Solo es requerida por los módulos secundarios: `Modules/SystemCards`, `Modules/Sidebars/Dashboard`, `Modules/Lock` y `Modules/Keystone`.
   - La barra no lo importa; por lo tanto, para un prototipo modular de la barra, no es bloqueante inmediato.

## 3. Comandos de resolución en gracie

1. **Herramientas de compilación oficiales:**
   ```bash
   sudo pacman -S --needed cmake ninja qt6-tools qtkeychain-qt6
   ```

2. **Librería de Cava (para build completo de `core`):**
   ```bash
   yay -S --needed libcava
   ```

3. **Módulo de diseño M3Shapes (para componentes de tarjetas/dock en runtime):**
   ```bash
   yay -S --needed qt6-m3shapes-git
   ```
