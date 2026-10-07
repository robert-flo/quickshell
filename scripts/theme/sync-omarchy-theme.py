#!/usr/bin/env python3
"""
sync-omarchy-theme.py: Convierte la paleta activa de Omarchy (colors.toml)
al formato colors.json consumido por Clavis (Material 3).
"""

import argparse
import json
import os
import subprocess
import sys
import tomllib
from pathlib import Path


def get_current_theme_name() -> str:
    """Detecta el nombre del tema activo de Omarchy."""
    # 1. Probar comando oficial omarchy theme current
    try:
        proc = subprocess.run(
            ["omarchy", "theme", "current"],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            return proc.stdout.strip()
    except Exception:
        pass

    # 2. Probar archivo de configuración de Omarchy
    config_file = Path.home() / ".config" / "omarchy" / "current_theme"
    if config_file.exists():
        content = config_file.read_text().strip()
        if content:
            return content

    # 3. Fallback predeterminado
    return "Tokyo Night"


def find_theme_colors_file(theme_name: str) -> Path | None:
    """Busca el archivo colors.toml correspondiente al tema."""
    slug = theme_name.lower().replace(" ", "-")

    search_dirs = [
        Path.home() / ".config" / "omarchy" / "themes" / slug,
        Path("/usr/share/omarchy/themes") / slug,
    ]

    for d in search_dirs:
        candidate = d / "colors.toml"
        if candidate.exists():
            return candidate

    return None


def convert_omarchy_to_m3(toml_data: dict) -> dict:
    """Mapea los campos de colors.toml a las propiedades de Appearance.qml."""
    bg = toml_data.get("background", "#1a1b26")
    fg = toml_data.get("foreground", "#a9b1d6")
    accent = toml_data.get("accent", "#7aa2f7")
    selection = toml_data.get("selection", "#292e42")
    muted = toml_data.get("muted", "#414868")

    return {
        "background": bg,
        "on_background": fg,
        "surface": bg,
        "surface_dim": toml_data.get("darker_background", bg),
        "surface_bright": toml_data.get("lighter_background", bg),
        "surface_container_lowest": toml_data.get("darker_background", bg),
        "surface_container_low": toml_data.get("dark_background", bg),
        "surface_container": toml_data.get("lighter_background", bg),
        "surface_container_high": selection,
        "surface_container_highest": selection,
        "on_surface": fg,
        "surface_variant": selection,
        "on_surface_variant": toml_data.get("dark_foreground", fg),
        "outline": muted,
        "outline_variant": selection,
        "primary": accent,
        "on_primary": bg,
        "primary_container": selection,
        "primary_fixed": accent,
        "secondary": toml_data.get("magenta", accent),
        "on_secondary": bg,
        "secondary_container": selection,
        "tertiary": toml_data.get("cyan", accent),
        "on_tertiary": bg,
        "tertiary_container": selection,
        "error": toml_data.get("red", "#f7768e"),
        "on_error": bg,
        "error_container": selection,
        "shadow": "#000000",
        "scrim": "#000000",
        "source_color": accent,
    }


def main():
    parser = argparse.ArgumentParser(description="Sincroniza temas de Omarchy con Clavis")
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="Ruta destino de colors.json (por defecto ~/.local/share/clavis/profiles/default/generated/clavis/colors.json)",
    )
    args = parser.parse_args()

    theme_name = get_current_theme_name()
    colors_file = find_theme_colors_file(theme_name)

    if not colors_file:
        print(f"Error: No se encontró colors.toml para el tema '{theme_name}'", file=sys.stderr)
        sys.exit(1)

    print(f"Sincronizando tema Omarchy: {theme_name} ({colors_file})")

    with open(colors_file, "rb") as f:
        toml_data = tomllib.load(f)

    m3_colors = convert_omarchy_to_m3(toml_data)

    target_paths = []
    if args.output:
        target_paths.append(args.output)
    else:
        # Destino canónico de Clavis
        default_target = (
            Path.home()
            / ".local"
            / "share"
            / "clavis"
            / "profiles"
            / "default"
            / "generated"
            / "clavis"
            / "colors.json"
        )
        target_paths.append(default_target)

    for path in target_paths:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(m3_colors, f, indent=2)
        print(f"✓ Paleta exportada en: {path}")


if __name__ == "__main__":
    main()
