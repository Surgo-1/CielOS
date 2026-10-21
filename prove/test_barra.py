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
TEMA = RADICE / "shell/servizi/Tema.qml"
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

    def test_i_sensori_nella_barra_hanno_l_icona_e_il_nome(self):
        s = SENSORI.read_text()
        self.assertIn("function icona(tipo)", s)
        for tipo in ("temp", "fan", "power", "in", "curr"):
            self.assertIn(tipo + ":", s)
        self.assertIn("Schedina", s)
        self.assertIn("voce.modelData.chip", s)
        self.assertIn("voce.modelData.nome", s)

    def test_tema_conosce_le_chiavi_della_barra(self):
        t = TEMA.read_text()
        for chiave in ("spazioBarra", "mostraLayout", "mostraVassoio", "mostraMedia", "mostraSensori", "mostraLuce",
                       "mostraSpegni", "finestreLayout", "chiaro"):
            self.assertIn(chiave, t)

    def test_le_impostazioni_hanno_la_pagina_barra(self):
        i = IMPOSTAZIONI.read_text()
        self.assertIn('nome: "Barra"', i)
        for chiave in ("barra_spazio", "barra_mostra_layout", "barra_mostra_sensori", "barra_mostra_orologio"):
            self.assertIn('"' + chiave + '"', i)
        self.assertIn('"finestre_layout"', i)

    def test_cieltema_conosce_e_scrive_il_layout(self):
        for chiave in ("finestre_layout", "barra_spazio", "barra_mostra_layout"):
            self.assertIn('"' + chiave + '"', CIELTEMA)
        self.assertIn('layout = "{scelte["finestre_layout"]}"', CIELTEMA)


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
