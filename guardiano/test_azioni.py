"""Le regole del guardiano, senza root e senza toccare niente: python3 -m unittest test_azioni (in guardiano/)."""
import unittest

import azioni as a


def no(test, *args, **kw):
    with test.assertRaises(a.Rifiutata):
        a.prepara(*args, **kw)


class Azioni(unittest.TestCase):
    def test_sconosciute_e_parametri_in_piu(self):
        no(self, "esegui_comando", {"cmd": "rm -rf /"})
        no(self, "installa", {"pacchetti": ["htop"], "opzioni": "--overwrite"})
        no(self, "firewall", {"porta": 22, "rete": "0.0.0.0/0"})         # la rete non si sceglie da fuori

    def test_installa(self):
        p = a.prepara("installa", {"pacchetti": "htop, btop htop"}, esiste=lambda n: True)
        self.assertEqual(p.comandi, [["pacman", "-S", "--needed", "--noconfirm", "--", "btop", "htop"]])
        self.assertTrue(p.istantanea)
        no(self, "installa", {"pacchetti": ["-Syu"]})
        no(self, "installa", {"pacchetti": ["htop; rm -rf /"]})
        no(self, "installa", {"pacchetti": ["yay-bin"]}, esiste=lambda n: False)
        no(self, "installa", {"pacchetti": []})

    def test_togli_protetti_anche_come_dipendenze(self):
        no(self, "togli", {"pacchetti": ["pacman"]})
        no(self, "togli", {"pacchetti": ["linux-cachyos"]})
        no(self, "togli", {"pacchetti": ["nvidia-utils"]})
        no(self, "togli", {"pacchetti": ["strano"]}, bersagli=lambda p: p + ["systemd-libs"])
        p = a.prepara("togli", {"pacchetti": ["htop"]}, bersagli=lambda p: p + ["libnl"])
        self.assertIn("libnl", p.frase)

    def test_servizi(self):
        p = a.prepara("servizio", {"nome": "ollama", "comando": "riavvia"})
        self.assertEqual(p.comandi, [["systemctl", "restart", "--", "ollama.service"]])
        a.prepara("servizio", {"nome": "sddm", "comando": "riavvia"})
        no(self, "servizio", {"nome": "sddm", "comando": "ferma"})
        no(self, "servizio", {"nome": "polkit", "comando": "riavvia"})
        no(self, "servizio", {"nome": "cielos-guardiano", "comando": "riavvia"})
        no(self, "servizio", {"nome": "systemd-logind", "comando": "disabilita"})
        no(self, "servizio", {"nome": "ollama", "comando": "mask"})
        no(self, "servizio", {"nome": "--root=/ ollama", "comando": "avvia"})

    def test_firewall_solo_casa(self):
        p = a.prepara("firewall", {"porta": 8770, "comando": "apri"}, rete="192.168.1.0/24")
        self.assertEqual(p.comandi, [["ufw", "allow", "from", "192.168.1.0/24", "to", "any", "port", "8770", "proto", "tcp"]])
        no(self, "firewall", {"porta": 8770}, rete="0.0.0.0/0")
        no(self, "firewall", {"porta": 8770}, rete="8.8.8.0/24")
        no(self, "firewall", {"porta": 8770}, rete=None)
        no(self, "firewall", {"porta": 70000}, rete="192.168.1.0/24")

    def test_aggiorna(self):
        self.assertIn("42", a.prepara("aggiorna", {}, info=lambda: 42).frase)
        no(self, "aggiorna", {}, info=lambda: 0)

    def test_istantanea_descrizione_pulita(self):
        p = a.prepara("istantanea", {"descrizione": "prima di $(rm -rf /) prova"})
        self.assertNotIn("$", p.comandi[0][-1])
        self.assertTrue(a.prepara("istantanee", {}).lettura)


if __name__ == "__main__":
    unittest.main()


class Dns(unittest.TestCase):
    def prepara(self, fornitore):
        return a.prepara("dns", {"fornitore": fornitore}, interfacce=["wlan0"],
                         dns_di=lambda d: ["192.168.1.1", "fe80::1"])

    def test_dns(self):
        p = self.prepara("cloudflare")
        self.assertEqual(p.comandi[0][:3], ["install", "-Dm644", "--"])
        self.assertTrue(p.comandi[0][3].endswith("sistema/dns/cloudflare.conf"))
        self.assertEqual(p.comandi[0][4], a.DNS_FILE)
        # [global-dns] non funziona con systemd-resolved: il DNS va messo in resolvectl
        self.assertEqual(p.comandi[1], ["rm", "-f", "--", a.DNS_VECCHIO])
        self.assertEqual(p.comandi[2], ["resolvectl", "dns", "wlan0",
                                        "1.1.1.1", "1.0.0.1",
                                        "2606:4700:4700::1111", "2606:4700:4700::1001"])
        p = self.prepara("automatico")
        self.assertEqual(p.comandi[0], ["rm", "-f", "--", a.DNS_FILE, a.DNS_VECCHIO])
        self.assertEqual(p.comandi[1], ["resolvectl", "dns", "wlan0", "192.168.1.1", "fe80::1"])
        no(self, "dns", {"fornitore": "../../etc/passwd"})
        no(self, "dns", {"fornitore": "cloudflare", "server": "6.6.6.6"})


class Sblocca(unittest.TestCase):
    def test_sblocca(self):
        p = a.prepara("sblocca", {}, al_lavoro=lambda: False)
        self.assertEqual(p.comandi, [["rm", "-f", "--", "/var/lib/pacman/db.lck"]])
        no(self, "sblocca", {}, al_lavoro=lambda: True)       # pacman sta lavorando: il lucchetto è suo
        no(self, "sblocca", {})                                # senza poterlo controllare: no
        no(self, "sblocca", {"file": "/etc/passwd"}, al_lavoro=lambda: False)


class Aggiornamenti(unittest.TestCase):
    def test_aggiorna_e_ondate(self):
        p = a.prepara("aggiorna", {}, info=lambda: 12)
        self.assertEqual(p.comandi, [["pacman", "-Syu", "--noconfirm"]])
        self.assertIn("12 pacchetti", p.frase)
        no(self, "aggiorna", {}, info=lambda: 0)
        no(self, "aggiorna", {"ondata": "2026-10-10"}, ondate=(False, None))          # ondate non attive
        no(self, "aggiorna", {"ondata": "10/10/2026"}, ondate=(True, None))
        no(self, "aggiorna", {"ondata": "2026-10-01"}, ondate=(True, "2026-10-05"))    # all'indietro: c'è «ritorna»
        p = a.prepara("aggiorna", {"ondata": "2026-10-10"}, ondate=(True, "2026-10-05"))
        self.assertEqual(p.comandi, [["pacman", "-Syyu", "--noconfirm"]])
        self.assertEqual(p.ondata, "2026-10-10")
        self.assertIn("10/10/2026", p.frase)
        no(self, "aggiorna", {"ondata": "2026-10-10", "pacchetti": ["x"]}, ondate=(True, None))

    def test_ritorna(self):
        no(self, "ritorna", {}, ultimo=lambda: None)
        p = a.prepara("ritorna", {}, ultimo=lambda: {"id": "x", "prima": "41", "data": "2026-10-14 10:00"})
        self.assertIn("istantanea 41", p.frase)
        self.assertFalse(p.istantanea)
