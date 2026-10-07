#!/usr/bin/env bash
# run-nested-bar.sh: Lanza Niri en ventana anidada dentro de Hyprland con el prototipo modular de Clavis Bar.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Iniciando laboratorio Niri + Clavis Bar (modo anidado) ==="

# Asegurar compilación de módulos si no existen
if [[ ! -d "$REPO_DIR/build/qml/Clavis/Niri" ]]; then
    echo "Compilando módulos nativos de Clavis..."
    cmake -S "$REPO_DIR" -B "$REPO_DIR/build" -G Ninja
    cmake --build "$REPO_DIR/build"
fi

CONFIG_FILE="$REPO_DIR/config/niri-nested.kdl"
ENTRYPOINT="$REPO_DIR/prototype_bar_shell.qml"

echo "Configuración Niri: $CONFIG_FILE"
echo "Entrypoint QML:     $ENTRYPOINT"
echo ""
echo "Atajos útiles dentro de la ventana de Niri:"
echo "  • Alt + Enter / Alt + T : Abrir terminal foot"
echo "  • Alt + Q              : Cerrar ventana activa"
echo "  • Alt + Left / Right   : Mover foco de columna"
echo "  • Alt + 1..5           : Cambiar de workspace"
echo "  • Alt + Shift + E      : Salir y cerrar la ventana anidada"
echo ""

export QML_IMPORT_PATH="$REPO_DIR/build/qml"

exec niri -c "$CONFIG_FILE" -- quickshell -p "$ENTRYPOINT"
