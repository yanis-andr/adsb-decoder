"""registres contre bit2registre (MATLAB) : les 27 trames de adsb_msgs.mat,
corrompues, bruitées, indicatif synthétique, adresse à zéro de tête, DF 18,
FTC 19."""

import numpy as np

from adsb.registres import bits_vers_registre
from conftest import champs_matlab, meme_registre


def test_registres_identiques(blocs_registres):
    blocs = blocs_registres
    ref_lon, ref_lat = float(blocs["reg_refLon"].item()), float(blocs["reg_refLat"].item())
    trames = blocs["reg_trames"]
    assert len(trames) == 27 * 3 + 4
    for i, t in enumerate(trames):
        meme_registre(bits_vers_registre(t, ref_lon, ref_lat), champs_matlab(blocs, "reg", i))
    assert blocs["reg_crcErrFlag"].sum() > 0


def test_adsb_msgs(blocs_registres):
    """Tâche 6 : un avion, 3420CA IBE3405, 25 positions et 2 identifications."""
    regs = [bits_vers_registre(t, -0.606629, 44.806884) for t in blocs_registres["adsb_msgs"]]
    assert all(r.erreur_crc == 0 and r.adresse == "3420CA" for r in regs)
    assert {r.indicatif for r in regs if r.indicatif} == {"IBE3405 "}
    assert sum(r.latitude is not None for r in regs) == 25


def test_adresse_zero_de_tete(blocs_registres):
    assert bits_vers_registre(blocs_registres["reg_trames"][-3], 0, 0).adresse == "0200AE"


def test_vitesse_hors_matlab():
    """FTC 19 (en plus du MATLAB) : deux trames réelles des buffers (405636 et 398446)."""
    def registre(hexa):
        bits = np.array([int(b) for b in bin(int(hexa, 16))[2:].zfill(112)], dtype=np.uint8)
        return bits_vers_registre(bits, -0.606629, 44.806884)

    r = registre("8D40563699404BAB08641D97A0D1")       # 405636
    assert round(r.vitesse_kt) == 351 and round(r.cap_deg) == 168 and r.taux_vertical_ft_min == -1536
    r = registre("8D398446990000001008004EA1AC")       # 398446 : vitesse indisponible
    assert r.vitesse_kt is None and r.cap_deg is None
