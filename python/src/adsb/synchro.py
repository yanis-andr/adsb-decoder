"""Synchronisation temporelle par corrélation avec le préambule (tâches 4 et 8).

estimer_retard est le portage de shift_estimation.m (une trame simulée) ;
correlation_buffer et candidats reprennent les étapes 2 et 3 de
process_buffer.m (tout un buffer réel d'un coup).
"""

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view


def estimer_retard(yl, sp, retard_max=None):
    """shift_estimation : retard (en échantillons, de 0 à retard_max) qui
    maximise |rho|, avec rho(d) = <yl[d:d+Lp], sp> / (||sp|| · ||yl[d:d+Lp]||).

    Rend (retard estimé, rho). Comme en MATLAB, une fenêtre d'énergie nulle
    donne rho = 0, et en cas d'égalité le premier maximum est retenu.
    """
    yl = np.asarray(yl).ravel()
    sp = np.asarray(sp).ravel()
    Lp = len(sp)
    if retard_max is None:
        retard_max = len(yl) - Lp
    nb = min(retard_max, len(yl) - Lp) + 1
    fenetres = sliding_window_view(yl, Lp)[:nb]       # une fenêtre par retard
    numerateur = (fenetres * np.conj(sp)).sum(axis=1)
    E_sp = np.sum(np.abs(sp) ** 2)
    E_yl = (np.abs(fenetres) ** 2).sum(axis=1)
    denominateur = np.sqrt(E_sp * E_yl)
    rho = np.zeros(nb, dtype=numerateur.dtype)
    ok = denominateur > 0
    rho[ok] = numerateur[ok] / denominateur[ok]
    return int(np.argmax(np.abs(rho))), rho


def estimer_retards_lot(yl, sp, retard_max):
    """estimer_retard sur plusieurs trames à la fois (une ligne par trame),
    un retard après l'autre : pour les simulations de TEB de la tâche 4."""
    yl = np.asarray(yl)
    sp = np.asarray(sp, dtype=float).ravel()
    Lp = len(sp)
    E_sp = np.sum(sp**2)
    rho = np.zeros((yl.shape[0], retard_max + 1))
    for d in range(retard_max + 1):
        fenetre = yl[:, d : d + Lp]
        numerateur = fenetre @ sp                      # sp réel : conj(sp) = sp
        denominateur = np.sqrt(E_sp * (np.abs(fenetre) ** 2).sum(axis=1))
        ok = denominateur > 0
        rho[ok, d] = np.abs(numerateur[ok]) / denominateur[ok]
    return np.argmax(rho, axis=1)


def correlation_buffer(y, p):
    """Corrélation normalisée de l'enveloppe y avec le préambule p, pour
    chaque début de fenêtre k (process_buffer, étape 2) :
        rho[k] = <y[k:k+Lp], p> / (||p|| · ||y[k:k+Lp]||).
    Le préambule ne vaut que 0 ou 1 : le numérateur est la somme des
    échantillons placés sous ses impulsions.
    """
    y = np.asarray(y, dtype=float)
    p = np.asarray(p, dtype=float)
    fenetres = sliding_window_view(y, len(p))
    numerateur = fenetres @ p
    energie = sliding_window_view(y**2, len(p)).sum(axis=1)
    rho = np.zeros(len(numerateur))
    ok = energie > 0
    rho[ok] = numerateur[ok] / np.sqrt(np.sum(p**2) * energie[ok])
    return rho


def candidats(rho, seuil, kmax):
    """Maxima locaux de rho (paliers compris : >= des deux côtés) au-dessus
    du seuil, et dont la trame tient dans le buffer (k <= kmax)."""
    gauche = np.r_[-np.inf, rho[:-1]]
    droite = np.r_[rho[1:], -np.inf]
    k = np.flatnonzero((rho >= seuil) & (rho >= gauche) & (rho >= droite))
    return k[k <= kmax]
