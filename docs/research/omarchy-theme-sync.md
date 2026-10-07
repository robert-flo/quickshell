# Investigación: Estrategia de sincronización de temas y colores entre Omarchy y Clavis

Investigación realizada para resolver el ticket [#13](https://github.com/robert-flo/quickshell/issues/13) de Wayfinder.

## 1. Motores de temas involucrados

1. **Omarchy (`colors.toml`):**
   - El tema activo se consulta mediante `omarchy theme current` (actualmente `Tokyo Night` en gracie).
   - Los valores de color están definidos en formato TOML en `/usr/share/omarchy/themes/<tema>/colors.toml` (o `~/.config/omarchy/themes/`).
   - Define roles semánticos: `mode`, `accent`, `background`, `lighter_background`, `foreground`, `muted`, `selection`, y colores de paleta ANSI (`red`, `green`, `blue`, etc.).

2. **Clavis Shell (`Appearance.qml` y `colors.json`):**
   - Consume un archivo JSON en `~/.local/share/clavis/profiles/default/generated/clavis/colors.json` (configurable mediante `CLAVIS_GENERATED_HOME`).
   - Clavis mapea las claves en snake_case a propiedades Material 3 en camelCase (`snakeToM3("surface_container")` -> `m3surfaceContainer`).
   - El componente `FileView` tiene `watchChanges: true`, por lo que cualquier actualización al archivo `colors.json` recarga la paleta del shell en caliente sin reiniciar Quickshell.

## 2. Mapeo de roles de color (Omarchy -> Material 3)

| Omarchy (`colors.toml`) | Clavis (`colors.json`) | Propiedad QML en `Appearance` |
| :--- | :--- | :--- |
| `background` | `background` / `surface` | `m3background`, `m3surface` |
| `lighter_background` | `surface_container` | `m3surfaceContainer` |
| `darker_background` | `surface_dim` | `m3surfaceDim` |
| `accent` | `primary` | `m3primary` |
| `background` (contrast) | `on_primary` | `m3onPrimary` |
| `foreground` | `on_surface` / `on_background` | `m3onSurface`, `m3onBackground` |
| `muted` | `outline` / `surface_variant` | `m3outline`, `m3surfaceVariant` |
| `selection` | `secondary_container` | `m3secondaryContainer` |
| `blue` / `cyan` | `secondary` / `tertiary` | `m3secondary`, `m3tertiary` |
| `red` | `error` | `m3error` |

## 3. Estrategia de sincronización recomendada

1. **Script de puente (`scripts/theme/sync-omarchy-theme.py`):**
   - Un script Python ligero que lee el tema activo de Omarchy vía `omarchy theme current`.
   - Carga el `colors.toml` correspondiente y genera el `colors.json` en la ruta esperada por Clavis.
   - Puede ejecutarse manualmente, al iniciar el script de pruebas `run-nested-bar.sh`, o integrarse a los hooks de Omarchy (`~/.config/omarchy/hooks/`) para sincronizarse automáticamente cuando el usuario cambie el tema del sistema.

2. **Beneficio:**
   - La barra y los widgets de Clavis adoptan instantáneamente la misma estética (Tokyo Night, Catppuccin, Gruvbox, etc.) que las terminales y ventanas de Omarchy, manteniendo consistencia visual absoluta.
