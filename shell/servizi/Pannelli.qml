pragma Singleton
// Quali pannelli della shell sono aperti (lanciatore, sessione), e su quale schermo.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    property bool lanciatore: false
    property bool sessione: false
    property string schermo: ""          // il nome dello schermo dove si aprono (quello che stai usando)
    // prova: la shell gira accanto a un'altra (caelestia) per essere guardata, senza prendersi spazio né tasti
    readonly property bool prova: Quickshell.env("CIELOS_PROVA") === "1"

    function apri(nome) {
        schermo = Hyprland.focusedMonitor?.name ?? "";
        lanciatore = nome === "lanciatore";
        sessione = nome === "sessione";
    }
    function chiudi() { lanciatore = false; sessione = false; }
    function dispatch(lua, vecchio) { Hyprland.dispatch(Hyprland.usingLua ? lua : vecchio); }
}
