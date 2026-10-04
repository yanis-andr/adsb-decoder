"""Export du portfolio : ce que le navigateur recalculera doit redonner les
mêmes bits et le même CRC."""

import numpy as np

from adsb.buffers import traiter_buffers
from adsb.crc import reste_crc
from adsb.ppm import demoduler_ppm
from adsb.portfolio import choisir_exemples, trame_pas_a_pas


def test_trames_pas_a_pas(buffers):
    tampons, _ = buffers
    messages = traiter_buffers(tampons)
    exemples = [trame_pas_a_pas(m, tampons[:, m.buffer - 1], nom) for nom, m in choisir_exemples(messages)]
    assert [e["categorie"] for e in exemples] == ["identite", "position", "vitesse"]
    assert [e["champs"]["ftc"] for e in exemples] == [4, 11, 19]
    for e in exemples:
        f = e["fenetre"]
        i, q = np.array(f["i"]), np.array(f["q"])
        y = np.sqrt(i * i + q * q)
        # la corrélation culmine au début du préambule
        assert int(np.argmax(f["correlation"])) == f["position_preambule"]
        # décision refaite à partir de i et q, aux instants exportés
        r1 = np.array([y[a].sum() for a in e["decision"]["instants_r1"]])
        r2 = np.array([y[a].sum() for a in e["decision"]["instants_r2"]])
        bits = (r1 > r2).astype(np.uint8)
        assert "".join(map(str, bits)) == e["bits"]
        assert not reste_crc(bits).any() and e["crc"]["reste"] == "0" * 24 and e["crc"]["recu"] == e["crc"]["calcule"]
        # variante bruitée : la copie propre se démodule en les mêmes bits
        v = e["variante_bruitee"]
        propre = np.array(v["signal_propre"], dtype=float)
        assert "".join(map(str, demoduler_ppm(propre[v["debut_donnees"]:], 4))) == e["bits"]
        assert v["modele"]["Eb"] == 2
