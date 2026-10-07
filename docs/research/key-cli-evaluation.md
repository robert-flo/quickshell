# Investigación: Evaluación de key-cli para el monitor de sistema de la barra en gracie

Investigación realizada para resolver el ticket [#12](https://github.com/robert-flo/quickshell/issues/12) de Wayfinder.

## 1. Contexto y protocolo

El widget `SysMonitor` de la barra consume el singleton `SystemMonitorService.qml`, el cual ejecuta en un subproceso continuo:

```bash
${CLAVIS_KEY:-key} sysmon stream --format jsonl --interval <ms> --modules cpu,disk,memory
```

Cada línea en stdout debe ser un objeto JSON con:
- `schemaVersion: 1`
- `timestampMs`: marca de tiempo en milisegundos.
- `sequence`: entero incremental (0, 1, 2...).
- `intervalMs`: intervalo de muestreo en ms.
- `cpu`: objeto con `usagePercent` (0-100), `temperatureCelsius`.
- `memory`: objeto con `usagePercent` (0-100), `usedBytes`, `totalBytes`.
- `disks`: array de objetos con `device`, `usagePercent`, `usedBytes`, `totalBytes`, `readBytesPerSecond`, `writeBytesPerSecond`.
- `errors`: array (usualmente vacío `[]`).

## 2. Opciones de resolución para el entorno de pruebas

1. **Opción A — Clonación e instalación de `key-cli` upstream:**
   - Proyecto Python independiente (`StatIndet/key-cli`).
   - Requiere crear un virtualenv e instalar drop-ins de systemd.
   - Provee además las utilidades de grabación de audio/pantalla y estado de teclado.

2. **Opción B — Emulador ligero de desarrollo (`mock-key-sysmon.py`):**
   - Un script Python autocontenido en `scripts/dev/mock-key-sysmon.py` que lee `/proc/stat`, `/proc/meminfo` y `os.statvfs('/')`.
   - Emite el stream JSONL v1 exacto que espera `SystemMonitorService`.
   - Se inyecta de forma transparente exportando `CLAVIS_KEY="$REPO_DIR/scripts/dev/mock-key-sysmon.py"`.
   - Permite que la barra muestre CPU, memoria y disco reales de gracie sin clonar ni instalar repositorios externos.

3. **Opción C — Exclusión modular:**
   - La barra funciona perfectamente sin `SysMonitor`; si no se desea métrica, se puede excluir `systemMonitor` de `PersonalizationConfig.barTrailingComponents`.

## 3. Conclusión y recomendación

Para el entorno modular de desarrollo en `explore/niri-bar-modular`, la mejor solución es la **Opción B**: proveer el script de emulación de métricas en `scripts/dev/mock-key-sysmon.py` para alimentar la barra de inmediato. Cuando el proyecto avance hacia el reemplazo permanente del escritorio de Omarchy, se puede evaluar la necesidad de forkear o empaquetar `key-cli` para el resto de herramientas secundarias.
