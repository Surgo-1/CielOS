"""La barra che si monta: icona del layout delle finestre (con l'animazione), sensori con la loro icona, e le
chiavi che la accendono e spengono dalle Impostazioni. Prove sul testo: la shell vera si guarda con
CIELOS_PROVA=1 qs -p shell.
python3 prove/test_barra.py"""
import unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
BARRA = RADICE / "shell/moduli/Barra.qml"
LAYOUT = RADICE / "shell/moduli/barra/Layout.qml"
ANTEPRIMA = RADICE / "shell/moduli/barra/AnteprimaLayout.qml"
SENSORI = RADICE / "shell/moduli/barra/SensoriBarra.qml"
BATTERIA = RADICE / "shell/moduli/barra/Batteria.qml"
LUCE = RADICE / "shell/moduli/barra/Luce.qml"
LUMINOSITA = RADICE / "shell/servizi/Luminosita.qml"
CONTENUTO = RADICE / "shell/moduli/blocco/Contenuto.qml"
BLOCCO = RADICE / "shell/moduli/Blocco.qml"
RIQUADRO = RADICE / "shell/moduli/Riquadro.qml"
MODELLI = RADICE / "shell/moduli/riquadro/Modelli.qml"
CONSIGLIATI = RADICE / "shell/moduli/riquadro/Consigliati.qml"
TEMA = RADICE / "shell/servizi/Tema.qml"
RETE = RADICE / "shell/moduli/barra/Rete.qml"
RETE_STATO = RADICE / "shell/servizi/ReteStato.qml"
IMPOSTAZIONI = RADICE / "shell/moduli/Impostazioni.qml"
CIELTEMA = (RADICE / "bin/cieltema").read_text()


class Barra(unittest.TestCase):
    def test_la_barra_ha_l_icona_del_layout_e_si_puo_spegnere(self):
        b = BARRA.read_text()
        self.assertIn("Layout { visible: Tema.mostraLayout }", b)
        self.assertIn("Tema.spazioBarra", b)
        for chiave in ("mostraNucleo", "mostraWorkspaces", "mostraVassoio", "mostraSistema",
                       "mostraSensori", "mostraVolume", "mostraRete", "mostraOrologio", "mostraSpegni"):
            self.assertIn("Tema." + chiave, b)
        self.assertNotIn("Luce { visible: Tema.mostraLuce", b)
        self.assertIn("columns: finestra.oriz ? 24 : 1", b)
        self.assertIn("mostraLuce", (RADICE / "shell/moduli/barra/Luce.qml").read_text())

    def test_l_icona_cambia_layout_e_salva_la_scelta(self):
        l = LAYOUT.read_text()
        self.assertIn("hyprctl\", \"eval\"", l)
        self.assertIn("general = { layout =", l)
        self.assertIn("\"finestre_layout=\" + prossimo", l)
        self.assertIn("SequentialAnimation", l)
        self.assertIn("AnteprimaLayout", l)
        for nome in ("dwindle", "master", "scrolling"):
            self.assertIn('"' + nome + '"', l)
        self.assertIn("onRotella", l)

    def test_l_anteprima_si_muove(self):
        a = ANTEPRIMA.read_text()
        self.assertIn('property string tipo', a)
        self.assertIn("Behavior on x", a)
        self.assertIn("Behavior on width", a)

    def test_la_rete_si_ascolta_una_volta_sola(self):
        """Una barra per schermo: se ognuna avesse il suo nmcli monitor, su due monitor ce ne sarebbero due (e due
        query all'avvio). Lo stato sta in un singleton, che tutte le barre leggono."""
        rete, stato = RETE.read_text(), RETE_STATO.read_text()
        self.assertNotIn('"nmcli", "monitor"', rete)
        self.assertNotIn("nmcli -t -f", rete)
        self.assertIn("ReteStato.tipo", rete)
        self.assertIn("ReteStato.connessioni", rete)
        self.assertIn('"nmcli", "monitor"', stato)
        self.assertIn("pragma Singleton", stato)
        self.assertIn("pdeathsig", stato)

    def test_i_sensori_nella_barra_hanno_l_icona_e_il_nome(self):
        s = SENSORI.read_text()
        self.assertIn("function icona(tipo)", s)
        for tipo in ("temp", "fan", "power", "in", "curr"):
            self.assertIn(tipo + ":", s)
        self.assertIn("Schedina", s)
        self.assertIn("voce.modelData.chip", s)
        self.assertIn("voce.modelData.nome", s)

    def test_la_batteria_mostra_livello_e_carica(self):
        """Il disegno cambia con la percentuale, il fulmine dice se è in carica, e l'icona si spegne dal pannello."""
        b = BATTERIA.read_text()
        self.assertIn("Quickshell.Services.UPower", b)
        self.assertIn("UPower.displayDevice", b)
        self.assertIn("isLaptopBattery", b)
        self.assertIn("battery_full", b)
        for nome in ("battery_6_bar", "battery_3_bar", "battery_0_bar", "bolt"):
            self.assertIn(nome, b)
        self.assertIn("timeToEmpty", b)
        self.assertIn("timeToFull", b)
        self.assertIn("in carica", b)
        self.assertIn("Batteria { attiva: Tema.mostraBatteria }", BARRA.read_text())

    def test_il_livello_viene_dalle_batterie_vere_non_dal_display_device(self):
        """Il DisplayDevice di UPower è una media di tutto (schede USB-C, batterie di mouse) e all'avvio può essere
        a 0: il livello si calcola dalle batterie del portatile, pesato sull'energia."""
        b = BATTERIA.read_text()
        self.assertIn("UPower.devices.values", b)
        self.assertIn("isLaptopBattery", b)
        self.assertIn("energyCapacity", b)
        self.assertIn('somma("energy")', b)
        self.assertIn("changeRate", b)
        self.assertIn("pile.length > 0", b)
        self.assertIn("Math.round(percentuale)", b)
        self.assertNotIn("Math.round(pila.percentage)", b)

    def test_tema_conosce_le_chiavi_della_barra(self):
        t = TEMA.read_text()
        for chiave in ("spazioBarra", "mostraLayout", "mostraVassoio", "mostraMedia", "mostraSensori", "mostraBatteria",
                       "mostraLuce", "mostraSpegni", "finestreLayout", "chiaro"):
            self.assertIn(chiave, t)

    def test_le_impostazioni_hanno_la_pagina_barra(self):
        i = IMPOSTAZIONI.read_text()
        self.assertIn('nome: "Barra"', i)
        for chiave in ("barra_spazio", "barra_mostra_layout", "barra_mostra_sensori", "barra_mostra_batteria", "barra_mostra_orologio"):
            self.assertIn('"' + chiave + '"', i)
        self.assertIn('"finestre_layout"', i)

    def test_cieltema_conosce_e_scrive_il_layout(self):
        for chiave in ("finestre_layout", "barra_spazio", "barra_mostra_layout", "barra_mostra_batteria"):
            self.assertIn('"' + chiave + '"', CIELTEMA)
        self.assertIn('layout = "{scelte["finestre_layout"]}"', CIELTEMA)


class Risorse(unittest.TestCase):
    """Niente lavoro periodico quando non succede niente (MAPPA.md, budget di leggerezza)."""

    def test_il_blocco_non_batte_da_sbloccato(self):
        c = CONTENUTO.read_text()
        self.assertIn("property bool attivo", c)
        self.assertIn("running: root.attivo", c)
        self.assertIn("running: Tema.animazioni && root.attivo", c)
        self.assertIn("attivo: serratura.locked", BLOCCO.read_text())

    def test_la_scheda_video_non_si_interroga_ogni_3_secondi(self):
        s = SENSORI.read_text()
        self.assertIn("interval: 15000", s)
        self.assertNotIn("if (sb.conNvidia && !nvidia.running)", s)

    def test_gli_scaricamenti_si_leggono_solo_mentre_scaricano(self):
        r = RIQUADRO.read_text()
        self.assertIn('q.scaricamenti.some(d => d.stato === "in corso")', r)
        self.assertIn("function svegliaScaricamenti()", r)
        self.assertIn("item.aggiorna.connect(() => q.svegliaScaricamenti())", r)
        self.assertIn('mo.scaricamenti.some(d => d.stato === "in corso")', MODELLI.read_text())

    def test_il_catalogo_dei_plugin_non_si_legge_all_avvio(self):
        c = CONSIGLIATI.read_text()
        self.assertIn("running: p.attiva && p.dati === null", c)
        self.assertIn("Timer { running: p.attiva;", c)
        self.assertNotIn("running: true", c)
        self.assertIn('attiva: ins.scheda === "consigliati"', (RADICE / "shell/moduli/riquadro/Install.qml").read_text())

    def test_la_luminosita_non_interroga_i2c_per_un_pannello_interno(self):
        l = LUCE.read_text()
        self.assertIn("Luminosita.salta(schermo)", l)
        self.assertIn("/^(eDP|LVDS)/i", l)
        self.assertIn("Tema.mostraLuce", l)
        self.assertIn("property var saltati", LUMINOSITA.read_text())


class MonitorEGiochi(unittest.TestCase):
    def test_il_monitor_stacca_la_ricerca_e_mostra_le_icone(self):
        m = (RADICE / "app/monitor/shell.qml").read_text()
        self.assertIn("topPadding: 8", m)
        self.assertIn("function iconaSensore", m)
        self.assertIn("app.iconaSensore(modelData.tipo)", m)

    def test_cielgiochi_cerca_davvero(self):
        g = (RADICE / "app/giochi/shell.qml").read_text()
        self.assertIn("function caricaDettagli", g)
        self.assertIn("onGiocoChanged", g)
        self.assertIn("caricaDettagli(gioco)", g)
        self.assertIn("Keys.onEscapePressed", g)
        self.assertIn("Nessun gioco si chiama così", g)
        # ProtonDB e anti-cheat affiancati
        self.assertIn("width: (parent.width - 14) / 2", g)

    def test_il_file_manager_mostra_il_file_che_trascina(self):
        f = (RADICE / "app/file/Pannello.qml").read_text()
        self.assertIn("trascinando", f)
        self.assertIn("puntoTrascina", f)
        self.assertIn("fantasma", f)
        self.assertIn("lampoAnim", f)
        self.assertIn("onPositionChanged", f)


if __name__ == "__main__":
    unittest.main(verbosity=2)
