pragma Singleton
// Quale pannello della Nightly è aperto, e su quale schermo. Uno alla volta, come in un HUD: aprire l'uno chiude l'altro.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    property string aperto: ""            // "" | lanciatore | centro | sessione
    property string schermo: ""           // il nome dello schermo che stai usando
    readonly property bool prova: Quickshell.env("CIELOS_NIGHTLY_PROVA") === "1"

    function mostra(nome) {
        schermo = Hyprland.focusedMonitor?.name ?? "";
        aperto = aperto === nome ? "" : nome;
    }
    function apri(nome) {
        schermo = Hyprland.focusedMonitor?.name ?? "";
        aperto = nome;
    }
    function chiudi() { aperto = ""; }
    function alterna(nome) { mostra(nome); }
}
