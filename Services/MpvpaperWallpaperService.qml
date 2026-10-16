pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Files
import qs.Common

Singleton {
    id: root

    readonly property string scriptPath: Quickshell.env("CLAVIS_MPVPAPER_SCRIPT")
                                         || Paths.scriptPath("system", "clavis-mpvpaper.sh")

    property bool active: false
    property string videoPath: ""
    property string thumbPath: ""
    property string lastError: ""
    property bool busy: applyProcess.running || clearProcess.running
    property var previewByPath: ({})
    property int previewRevision: 0
    property var thumbQueue: []
    property string pendingThumbVideo: ""
    property string pendingVideo: ""

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

    function resetState() {
        root.active = false;
        root.videoPath = "";
        root.thumbPath = "";
        root.pendingVideo = "";
    }

    function rememberPreview(path, thumb) {
        const key = String(path || "").trim();
        const value = String(thumb || "").trim();
        if (!key || !value)
            return;
        const next = Object.assign({}, root.previewByPath);
        if (next[key] === value)
            return;
        next[key] = value;
        root.previewByPath = next;
        root.previewRevision += 1;
    }

    function xdgPreview(path) {
        const url = Paths.fileUrl(path);
        try {
            const thumb = DesktopFiles.thumbnail(url);
            return thumb && String(thumb) !== "" ? String(thumb) : "";
        } catch (error) {
            return "";
        }
    }

    function previewUrl(path) {
        const normalized = String(path || "").trim();
        if (!normalized)
            return "";
        const xdg = root.xdgPreview(normalized);
        if (xdg)
            return xdg;
        const cached = root.previewByPath[normalized];
        if (cached)
            return Paths.fileUrl(cached);
        if (normalized === root.videoPath && root.thumbPath)
            return Paths.fileUrl(root.thumbPath);
        root.ensurePreview(normalized);
        return "";
    }

    function ensurePreview(path) {
        const normalized = String(path || "").trim();
        if (!normalized)
            return;
        if (root.previewByPath[normalized] || root.xdgPreview(normalized))
            return;
        if (root.pendingThumbVideo === normalized)
            return;
        if (root.thumbQueue.indexOf(normalized) >= 0)
            return;
        root.thumbQueue = root.thumbQueue.concat([normalized]);
        root.pumpThumbQueue();
    }

    function ensurePreviews(paths) {
        const list = Array.isArray(paths) ? paths : [];
        for (let i = 0; i < list.length; i += 1)
            root.ensurePreview(list[i]);
    }

    function pumpThumbQueue() {
        if (thumbProcess.running || root.thumbQueue.length === 0)
            return;
        const next = String(root.thumbQueue[0] || "").trim();
        root.thumbQueue = root.thumbQueue.slice(1);
        if (!next) {
            Qt.callLater(root.pumpThumbQueue);
            return;
        }
        if (root.previewByPath[next] || root.xdgPreview(next)) {
            Qt.callLater(root.pumpThumbQueue);
            return;
        }
        root.pendingThumbVideo = next;
        thumbProcess.command = ["bash", root.scriptPath, "thumb", next];
        thumbProcess.running = true;
    }

    function parseThumbPath(output) {
        const lines = String(output || "").split("\n");
        for (let i = 0; i < lines.length; i += 1) {
            const line = lines[i].trim();
            if (line.startsWith("THUMB_PATH="))
                return line.slice("THUMB_PATH=".length);
        }
        return "";
    }

    Process {
        id: applyProcess
        stdout: StdioCollector {
            id: applyStdout
        }
        onExited: exitCode => {
            const thumb = root.parseThumbPath(applyStdout.text);
            if (exitCode !== 0 || !thumb) {
                root.lastError = String(applyProcess.stderr.text || "").trim() || qsTr(
                            "Failed to start mpvpaper");
                root.resetState();
                return;
            }
            root.videoPath = root.pendingVideo;
            root.rememberPreview(root.pendingVideo, thumb);
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

    Process {
        id: thumbProcess
        stdout: StdioCollector {
            id: thumbStdout
        }
        onExited: exitCode => {
            const path = root.pendingThumbVideo;
            root.pendingThumbVideo = "";
            const thumb = root.parseThumbPath(thumbStdout.text);
            if (exitCode === 0 && thumb)
                root.rememberPreview(path, thumb);
            Qt.callLater(root.pumpThumbQueue);
        }
    }
}
