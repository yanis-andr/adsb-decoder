"""Modulation et démodulation PPM (tâche 1).

Portage de modulatePPM.m, get_preamble.m (et preambule.m) et demodulatePPM.m.
Un symbole dure Ts = Fse échantillons : impulsion dans la première moitié
pour un 1, dans la seconde pour un 0, aucune impulsion pour -1 (préambule).
"""

import numpy as np


def moduler_ppm(symboles, Fse):
    """modulatePPM : 1 -> impulsion en début de symbole, 0 -> en fin, -1 -> rien."""
    symboles = np.asarray(symboles).ravel()
    p1 = np.r_[np.ones(Fse // 2), np.zeros(Fse // 2)]
    p0 = np.r_[np.zeros(Fse // 2), np.ones(Fse // 2)]
    pvide = np.zeros(Fse)
    # une ligne par symbole, puis mise bout à bout
    formes = np.where(symboles[:, None] == 0, p0, np.where(symboles[:, None] == -1, pvide, p1))
    return formes.ravel()


def preambule(Fse):
    """get_preamble : impulsions à 0 ; 1 ; 3,5 et 4,5 µs (8 µs en tout).

    preambule.m (tâche 4) construit le même motif demi-symbole par demi-symbole.
    """
    return moduler_ppm([1, 1, -1, 0, 0, -1, -1, -1], Fse)


def demoduler_ppm(paquet, Fse):
    """demodulatePPM : filtre adapté (somme sur chaque demi-symbole) puis décision.

    Signal réel : maximum de vraisemblance r1 > r2 (tâche 1, ST3) ; une
    égalité donne 0. Signal complexe (phase inconnue) : |r1| > |r2| (tâche 4,
    ST4). Comme isreal en MATLAB, c'est le type du tableau qui décide.
    """
    paquet = np.asarray(paquet).ravel()
    symboles = paquet.reshape(-1, Fse)          # une ligne par symbole
    r1 = symboles[:, : Fse // 2].sum(axis=1)
    r2 = symboles[:, Fse // 2 :].sum(axis=1)
    if np.iscomplexobj(paquet):
        return (np.abs(r1) > np.abs(r2)).astype(np.uint8)
    return (r1 > r2).astype(np.uint8)


def demoduler_ppm_lot(paquets, Fse):
    """Même décision sur plusieurs paquets réels à la fois (une ligne par paquet).
    Signal réel seulement (enveloppe) : r1 > r2."""
    paquets = np.asarray(paquets)
    assert not np.iscomplexobj(paquets), "demoduler_ppm_lot attend un signal réel"
    symboles = paquets.reshape(paquets.shape[0], -1, Fse)
    r1 = symboles[:, :, : Fse // 2].sum(axis=2)
    r2 = symboles[:, :, Fse // 2 :].sum(axis=2)
    return (r1 > r2).astype(np.uint8)
