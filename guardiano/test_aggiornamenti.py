"""La parte da amministratore degli aggiornamenti, in una cartella finta al posto di / (CIELOS_RADICE), senza root:
python3 -m unittest test_aggiornamenti (in guardiano/). Il ritorno indietro vero (btrfs) si prova nella VM."""
import importlib, json, os, tempfile, unittest
from pathlib import Path


class Prova(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.r = Path(self.t.name)
        os.environ["CIELOS_RADICE"] = self.t.name
        import aggiornamenti
        self.A = importlib.reload(aggiornamenti)

    def tearDown(self):
        self.t.cleanup()
        del os.environ["CIELOS_RADICE"]

    def kernel(self, ver, base, boot_files, nvidia=None):
        d = self.r / "usr/lib/modules" / ver
        d.mkdir(parents=True)
        (d / "modules.dep").write_text("")
        (d / "vmlinuz").write_text("k")
        (d / "pkgbase").write_text(base + "\n")
        if nvidia:
            (d / "updates/dkms").mkdir(parents=True)
            (d / "updates/dkms/nvidia.ko.zst").write_text("m")
        for f in boot_files:
            (self.r / "boot" / f).parent.mkdir(parents=True, exist_ok=True)
            (self.r / "boot" / f).write_text(f)

    def test_controlli_dopo_grub(self):
        self.kernel("6.17.1-arch1-1", "linux", ["vmlinuz-linux", "initramfs-linux.img"])
        self.assertEqual(self.A.controlli_dopo(), [])
        (self.r / "boot/initramfs-linux.img").unlink()
        self.assertEqual(self.A.controlli_dopo(), ["kernel linux: manca l'initramfs"])

    def test_controlli_dopo_limine_e_nvidia(self):
        mid = "0123abcd"
        self.kernel("7.2.9-2-cachyos", "linux-cachyos",
                    [f"{mid}/linux-cachyos/vmlinuz-linux-cachyos", f"{mid}/linux-cachyos/initramfs-linux-cachyos"], nvidia=True)
        self.kernel("6.12.50-1-cachyos-lts", "linux-cachyos-lts",
                    [f"{mid}/linux-cachyos-lts/vmlinuz-linux-cachyos-lts", f"{mid}/linux-cachyos-lts/initramfs-linux-cachyos-lts"])
        (self.r / "usr/bin").mkdir(parents=True)
        (self.r / "usr/bin/nvidia-smi").write_text("")
        self.assertEqual(self.A.controlli_dopo(), ["kernel 6.12.50-1-cachyos-lts: manca il modulo NVIDIA (dkms non l'ha compilato)"])

    def test_copia_e_rimetti_avvio(self):
        self.kernel("6.17.1-arch1-1", "linux", ["vmlinuz-linux", "initramfs-linux.img", "grub/grub.cfg", "grub/fonts/x.pf2"])
        copiati = self.A.copia_avvio("u1")
        self.assertEqual(sorted(copiati), ["grub/grub.cfg", "initramfs-linux.img", "vmlinuz-linux"])
        (self.r / "boot/vmlinuz-linux").write_text("NUOVO")
        self.A.rimetti_avvio(self.r, "u1")
        self.assertEqual((self.r / "boot/vmlinuz-linux").read_text(), "vmlinuz-linux")

    def test_ondata_e_in_prova(self):
        self.assertFalse(self.A.ondate_attive())
        (self.r / "etc").mkdir()
        (self.r / "etc/pacman.conf").write_text("[core]\nInclude = /etc/pacman.d/cielos-ondata\n")
        self.assertTrue(self.A.ondate_attive())
        self.A.metti_ondata("2026-10-10")
        self.assertEqual(self.A.ondata_attuale(), "2026-10-10")
        self.assertIn("/repos/2026/10/10/$repo/os/$arch", (self.r / "etc/pacman.d/cielos-ondata").read_text())
        with self.assertRaises(ValueError):
            self.A.metti_ondata("2099-01-01")
        self.A.segna_in_prova("u1", "40", "41", "2026-10-10")
        self.assertTrue(any("non è ancora stato confermato" in x for x in self.A.controlli_prima()))
        self.A.conferma()
        self.assertFalse(self.A.IN_PROVA.exists())
        self.assertEqual(json.loads(self.A.STORICO.read_text())[-1]["esito"], "ok")


class Avvio(unittest.TestCase):
    """la decisione al terzo avvio senza desktop: si torna indietro (senza aspettare niente)"""
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        os.environ["CIELOS_RADICE"] = self.t.name
        import aggiornamenti, avvio
        self.A = importlib.reload(aggiornamenti)
        self.V = importlib.reload(avvio)

    def tearDown(self):
        self.t.cleanup()
        del os.environ["CIELOS_RADICE"]

    def test_troppi_tentativi(self):
        fatti = []
        self.V.torna_e_riavvia = lambda p, m: fatti.append((p["prima"], m))
        self.A.segna_in_prova("u1", "40", "41", None)
        p = json.loads(self.A.IN_PROVA.read_text())
        p["tentativi"] = self.A.TENTATIVI_MAX
        self.A._scrivi(self.A.IN_PROVA, p)
        self.V.main()
        self.assertEqual(fatti[0][0], "40")

    def test_niente_in_prova(self):
        self.V.main()                    # esce subito
        self.assertFalse(self.A.IN_PROVA.exists())


if __name__ == "__main__":
    unittest.main()
