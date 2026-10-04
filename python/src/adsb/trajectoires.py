"""Durée couverte par les 9 buffers, estimée par les vitesses annoncées.

buffers.mat ne contient aucune date. Chaque buffer dure 0,5 s, mais les
avions se déplacent de 20 à 27 km du buffer 1 au buffer 9 : les buffers
ne sont pas consécutifs. Méthode (README.md) : pour chaque avion
et chaque paire de buffers consécutifs où il a une position, distance
parcourue / vitesse annoncée = somme des intervalles entre ces deux
buffers ; les 8 intervalles sont résolus par moindres carrés.
Choix : toutes les positions décodées (FTC 9 à 18), la première de chaque
buffer, la moyenne des vitesses sol annoncées (FTC 19) de l'avion, et la
distance sur une sphère de rayon moyen 6 371 km.
"""

import numpy as np

RAYON_TERRE = 6371.0088e3   # m
NOEUD = 1852 / 3600         # m/s


def distance(lat1, lon1, lat2, lon2):
    """Distance du grand cercle (formule de haversine), en mètres."""
    la1, lo1, la2, lo2 = map(np.radians, (lat1, lon1, lat2, lon2))
    h = np.sin((la2 - la1) / 2) ** 2 + np.cos(la1) * np.cos(la2) * np.sin((lo2 - lo1) / 2) ** 2
    return float(2 * RAYON_TERRE * np.arcsin(np.sqrt(h)))


def positions_et_vitesses(messages):
    """Par adresse : première position (lat, lon) de chaque buffer et vitesses sol annoncées."""
    avions = {}
    for m in messages:
        r = m.registre
        a = avions.setdefault(r.adresse, {"positions": {}, "vitesses": []})
        if r.latitude is not None:
            a["positions"].setdefault(m.buffer, (r.latitude, r.longitude))
        if r.vitesse_kt is not None:
            a["vitesses"].append(r.vitesse_kt)
    return avions


def estimer_intervalles(messages, nb_buffers=9):
    """Rend les intervalles entre buffers consécutifs (s), le résidu quadratique
    moyen par segment (s), et les segments utilisés."""
    lignes, durees, segments = [], [], []
    for adresse, a in positions_et_vitesses(messages).items():
        buffers = sorted(a["positions"])
        if not a["vitesses"] or len(buffers) < 2:
            continue
        v = np.mean(a["vitesses"]) * NOEUD
        for b1, b2 in zip(buffers, buffers[1:]):
            d = distance(*a["positions"][b1], *a["positions"][b2])
            ligne = np.zeros(nb_buffers - 1)
            ligne[b1 - 1 : b2 - 1] = 1          # intervalles entre b1 et b2
            lignes.append(ligne)
            durees.append(d / v)
            segments.append({"adresse": adresse, "de": b1, "a": b2, "distance_m": d, "duree_s": d / v})
    A, s = np.array(lignes), np.array(durees)
    intervalles, *_ = np.linalg.lstsq(A, s, rcond=None)
    residu = float(np.sqrt(np.mean((A @ intervalles - s) ** 2)))
    return intervalles, residu, segments


def premier_dernier(messages):
    """Avions vus aux buffers 1 et 9 : distance parcourue et durée à la vitesse annoncée."""
    res = []
    for adresse, a in positions_et_vitesses(messages).items():
        if 1 in a["positions"] and 9 in a["positions"] and a["vitesses"]:
            d = distance(*a["positions"][1], *a["positions"][9])
            v = float(np.mean(a["vitesses"]))
            res.append({"adresse": adresse, "distance_m": d, "vitesse_kt": v, "duree_s": d / (v * NOEUD)})
    return res
