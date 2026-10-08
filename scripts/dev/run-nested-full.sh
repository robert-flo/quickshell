#!/usr/bin/env bash
# run-nested-full.sh: Lanza todo el shell upstream de Clavis (Bar, Dock, DesktopCards, Keystone)
# dentro de Niri en ventana anidada en Hyprland como experimento de visualización.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Lanzando Clavis Shell completo upstream en Niri anidado ==="

CONFIG_FILE="$REPO_DIR/config/niri-nested.kdl"
ENTRYPOINT="$REPO_DIR/shell.qml"

# Sincronizar colores del tema activo de Omarchy hacia Clavis
if [[ -f "$REPO_DIR/scripts/theme/sync-omarchy-theme.py" ]]; then
    python3 "$REPO_DIR/scripts/theme/sync-omarchy-theme.py"
fi

echo "Configuración Niri: $CONFIG_FILE"
echo "Entrypoint QML:     $ENTRYPOINT (UPSTREAM FULL SHELL)"
echo ""
echo "Atajos dentro de la ventana de Niri:"
echo "  • Alt + Enter / Alt + T : Abrir terminal foot"
echo "  • Alt + Q              : Cerrar ventana activa"
echo "  • Alt + Left / Right   : Mover foco de columna"
echo "  • Alt + 1..5           : Cambiar de workspace"
echo "  • Alt + Shift + E      : Salir y cerrar la ventana anidada"
echo ""

export QML_IMPORT_PATH="$REPO_DIR/build/qml"

# Configurar emulador de key-cli para métricas
MOCK_KEY="$REPO_DIR/scripts/dev/mock-key-sysmon.py"
if [[ -f "$MOCK_KEY" ]]; then
    chmod +x "$MOCK_KEY"
    export CLAVIS_KEY="$MOCK_KEY"
    echo "Monitor del sistema: activado con emulador ligero ($MOCK_KEY)"
fi

exec niri -c "$CONFIG_FILE" -- quickshell -p "$ENTRYPOINT"
