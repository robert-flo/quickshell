pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string scriptPath: Quickshell.env("CLAVIS_MPVPAPER_SCRIPT")
                                         || "/etc/xdg/quickshell/clavis/scripts/system/clavis-mpvpaper.sh"

    property bool active: false
    property string videoPath: ""
    property string thumbPath: ""
    property string lastError: ""
    property bool busy: applyProcess.running || clearProcess.running

    function apply(path) {
        const normalized = String(path || "").trim();
        if (!normalized)
            return false;
        if (applyProcess.running)
            return false;
        root.lastError = "";
        root.pendingVideo = normalized;
        applyProcess.command = ["bash", root.scriptPath, "apply", normalized];
        applyProcess.running = true;
        return true;
    }

    function clear() {
        if (!root.active && !root.videoPath)
            return;
        if (clearProcess.running)
            return;
        clearProcess.command = ["bash", root.scriptPath, "clear"];
        clearProcess.running = true;
    }

    property string pendingVideo: ""

    function resetState() {
        root.active = false;
        root.videoPath = "";
        root.thumbPath = "";
        root.pendingVideo = "";
    }

    Process {
        id: applyProcess
        stdout: StdioCollector {
            id: applyStdout
        }
        onExited: exitCode => {
            const output = String(applyStdout.text || "");
            let thumb = "";
            const lines = output.split("\n");
            for (let i = 0; i < lines.length; i += 1) {
                const line = lines[i].trim();
                if (line.startsWith("THUMB_PATH="))
                    thumb = line.slice("THUMB_PATH=".length);
            }
            if (exitCode !== 0 || !thumb) {
                root.lastError = String(applyProcess.stderr.text || "").trim() || qsTr(
                            "Failed to start mpvpaper");
                root.resetState();
                return;
            }
            root.videoPath = root.pendingVideo;
            root.pendingVideo = "";
            root.thumbPath = thumb;
            root.active = true;
            root.lastError = "";
        }
    }

    Process {
        id: clearProcess
        onExited: exitCode => {
            if (exitCode !== 0)
                root.lastError = String(clearProcess.stderr.text || "").trim() || qsTr(
                            "Failed to stop mpvpaper");
            root.resetState();
        }
    }
}
