//@ pragma UseQApplication
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1

import QtQuick
import Quickshell
import qs.Modules.Bar
import qs.Common
import qs.Services

ShellRoot {
    id: root

    Component.onCompleted: {
        console.log("PROTOTYPE: Inicializando servicios base para Bar aislada...");
        I18nService.initialize();
        DisplayColor.evaluate();
        console.log("PROTOTYPE: Bar montada exitosamente en Niri.");
    }

    Bar {}
}
