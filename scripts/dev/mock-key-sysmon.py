#!/usr/bin/env python3
"""
mock-key-sysmon.py: Emulador ligero de key sysmon v1 para desarrollo y pruebas en gracie.
Genera métricas reales del sistema leyendo /proc y statvfs sin requerir key-cli.
"""
import sys
import os
import time
import json
import glob
import signal
import socket
import platform

try:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except Exception:
    pass

def signal_handler(sig, frame):
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def get_cpu_info():
    """Lee el modelo de CPU de /proc/cpuinfo."""
    model = "Unknown CPU"
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if "model name" in line:
                    model = line.split(":", 1)[1].strip()
                    break
    except Exception:
        pass
    return model

def get_boot_time_ms():
    """Lee el timestamp de arranque en ms desde /proc/stat."""
    try:
        with open("/proc/stat") as f:
            for line in f:
                if line.startswith("btime "):
                    return int(line.split()[1]) * 1000
    except Exception:
        pass
    return int((time.time() - 3600) * 1000)

def get_cpu_temperature():
    """Busca la temperatura del CPU en /sys/class/hwmon."""
    # Prioridad: coretemp / k10temp Package id 0
    package_temp = None
    fallback_temp = None
    try:
        for hwmon in glob.glob("/sys/class/hwmon/hwmon*"):
            name = ""
            try:
                with open(os.path.join(hwmon, "name")) as f:
                    name = f.read().strip()
            except Exception:
                pass

            for temp_input in glob.glob(os.path.join(hwmon, "temp*_input")):
                label_path = temp_input.replace("_input", "_label")
                label = ""
                try:
                    with open(label_path) as lf:
                        label = lf.read().strip()
                except Exception:
                    pass

                try:
                    with open(temp_input) as tf:
                        val = int(tf.read().strip()) / 1000.0
                        if fallback_temp is None:
                            fallback_temp = val
                        if "Package" in label or (name in ("coretemp", "k10temp") and "temp1" in temp_input):
                            package_temp = val
                            break
                except Exception:
                    pass
            if package_temp is not None:
                break
    except Exception:
        pass

    return package_temp if package_temp is not None else (fallback_temp if fallback_temp is not None else 45.0)

class SysSampler:
    def __init__(self):
        self.prev_cpu_total = None
        self.prev_cpu_idle = None
        self.prev_net_rx = None
        self.prev_net_tx = None
        self.prev_time = time.time()

    def sample_cpu(self):
        try:
            with open("/proc/stat") as f:
                line = f.readline()
            parts = [float(x) for x in line.split()[1:]]
            idle = parts[3] + (parts[4] if len(parts) > 4 else 0)
            total = sum(parts)
            if self.prev_cpu_total is not None and (total - self.prev_cpu_total) > 0:
                diff_total = total - self.prev_cpu_total
                diff_idle = idle - self.prev_cpu_idle
                usage_pct = max(0.0, min(100.0, ((diff_total - diff_idle) / diff_total) * 100.0))
            else:
                usage_pct = 0.0
            self.prev_cpu_total = total
            self.prev_cpu_idle = idle
        except Exception:
            usage_pct = 0.0

        temp = get_cpu_temperature()
        return {
            "usagePercent": round(usage_pct, 1),
            "temperatureCelsius": round(temp, 1),
            "packageTemperatureCelsius": round(temp, 1),
            "frequencyMHz": 2400.0
        }

    def sample_memory(self):
        total = 0
        avail = 0
        try:
            with open("/proc/meminfo") as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        total = int(line.split()[1]) * 1024
                    elif line.startswith("MemAvailable:"):
                        avail = int(line.split()[1]) * 1024
            if avail == 0:
                avail = total // 2
            used = max(0, total - avail)
            usage_pct = (used / total * 100.0) if total > 0 else 0.0
        except Exception:
            total = 16 * 1024 * 1024 * 1024
            used = 8 * 1024 * 1024 * 1024
            avail = total - used
            usage_pct = 50.0

        return {
            "totalBytes": total,
            "usedBytes": used,
            "availableBytes": avail,
            "usagePercent": round(usage_pct, 1)
        }

    def sample_disks(self):
        try:
            s = os.statvfs("/")
            total = s.f_blocks * s.f_frsize
            free = s.f_bfree * s.f_frsize
            avail = s.f_bavail * s.f_frsize
            used = total - free
            usage_pct = (used / total * 100.0) if total > 0 else 0.0
        except Exception:
            total = 250 * 1024 * 1024 * 1024
            used = 120 * 1024 * 1024 * 1024
            free = total - used
            avail = free
            usage_pct = 48.0

        return [{
            "device": "root",
            "mountPoint": "/",
            "totalBytes": total,
            "usedBytes": used,
            "freeBytes": free,
            "availableBytes": avail,
            "usagePercent": round(usage_pct, 1),
            "readBytesPerSecond": 0.0,
            "writeBytesPerSecond": 0.0
        }]

    def sample_network(self, dt):
        rx = 0
        tx = 0
        try:
            with open("/proc/net/dev") as f:
                lines = f.readlines()[2:]
                for line in lines:
                    parts = line.split(":")
                    if len(parts) == 2:
                        dev = parts[0].strip()
                        if dev == "lo":
                            continue
                        stats = parts[1].split()
                        rx += int(stats[0])
                        tx += int(stats[8])
        except Exception:
            pass

        rx_rate = 0.0
        tx_rate = 0.0
        if self.prev_net_rx is not None and dt > 0:
            rx_rate = max(0.0, (rx - self.prev_net_rx) / dt)
            tx_rate = max(0.0, (tx - self.prev_net_tx) / dt)

        self.prev_net_rx = rx
        self.prev_net_tx = tx

        return {
            "downloadBytesPerSecond": round(rx_rate, 1),
            "uploadBytesPerSecond": round(tx_rate, 1)
        }

def run_stream(interval_ms, modules_set):
    interval_s = max(0.2, interval_ms / 1000.0)
    sampler = SysSampler()
    # Muestra inicial para calibrar delta de CPU y red
    sampler.sample_cpu()
    sampler.sample_network(0)
    time.sleep(0.1)

    sequence = 0
    prev_time = time.time()

    while True:
        now = time.time()
        dt = max(0.001, now - prev_time)
        prev_time = now

        snapshot = {
            "schemaVersion": 1,
            "sequence": sequence,
            "timestampMs": int(now * 1000),
            "intervalMs": interval_ms,
            "errors": []
        }

        if "cpu" in modules_set:
            snapshot["cpu"] = sampler.sample_cpu()
        if "memory" in modules_set:
            snapshot["memory"] = sampler.sample_memory()
        if "disk" in modules_set:
            snapshot["disks"] = sampler.sample_disks()
        if "network" in modules_set:
            snapshot["network"] = sampler.sample_network(dt)
        if "gpu" in modules_set:
            snapshot["gpus"] = []

        print(json.dumps(snapshot), flush=True)
        sequence += 1
        time.sleep(interval_s)

def run_system():
    payload = {
        "schemaVersion": 1,
        "system": {
            "systemUser": os.environ.get("USER", "tanjiro"),
            "hostName": socket.gethostname(),
            "wmName": "niri",
            "shellName": "clavis",
            "kernel": platform.release(),
            "architecture": platform.machine(),
            "chassis": "Desktop",
            "vendor": "",
            "productName": "",
            "boardName": "",
            "biosVersion": "",
            "cpuModelName": get_cpu_info(),
            "physicalCoreCount": os.cpu_count() or 4,
            "logicalCpuCount": os.cpu_count() or 4,
            "bootTimeMs": get_boot_time_ms(),
            "osAgeText": "",
            "distroId": "arch",
            "distroName": "Arch Linux"
        }
    }
    print(json.dumps(payload), flush=True)

def main():
    args = sys.argv[1:]
    if not args:
        print(json.dumps({"schemaVersion": 1, "ok": True}))
        return

    cmd = args[0]
    if cmd == "sysmon":
        subcmd = args[1] if len(args) > 1 else ""
        if subcmd == "stream":
            interval = 2000
            modules = {"cpu", "memory", "disk"}
            idx = 2
            while idx < len(args):
                if args[idx] == "--interval" and idx + 1 < len(args):
                    try:
                        interval = int(args[idx + 1])
                    except ValueError:
                        pass
                    idx += 2
                elif args[idx] == "--modules" and idx + 1 < len(args):
                    modules = set(args[idx + 1].split(","))
                    idx += 2
                else:
                    idx += 1
            run_stream(interval, modules)
            return
        elif subcmd == "system":
            run_system()
            return

    # Fallback genérico para otros comandos de key (ipc, file, etc.)
    print(json.dumps({"schemaVersion": 1, "ok": True}), flush=True)

if __name__ == "__main__":
    main()
