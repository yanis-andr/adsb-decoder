"""Décodage CPR local (tâche 6) : portage de cprMod.m, cprNL.m et cpr2LatLon.m."""

import numpy as np

NZ = 15   # zones de latitude
NB = 17   # bits de la latitude et de la longitude codées


def cpr_mod(a, b):
    """cprMod : reste toujours positif, a - b·floor(a/b)."""
    return a - b * np.floor(a / b)


def _cpr_nl_scalaire(lat):
    # cas particuliers (annexe du sujet)
    if abs(lat) < 0.0001:
        return 59
    if abs(abs(lat) - 87) < 0.0001:
        return 2
    if abs(lat) > 87:
        return 1
    numerateur = 1 - np.cos(np.pi / (2 * NZ))
    denominateur = np.cos(np.pi * abs(lat) / 180) ** 2
    if denominateur == 0:
        return 1
    interieur = min(max(1 - numerateur / denominateur, -1.0), 1.0)
    return int(np.floor((2 * np.pi) / np.arccos(interieur)))


def cpr_nl(lat):
    """cprNL : nombre de zones de longitude à la latitude lat (scalaire ou tableau)."""
    if np.ndim(lat) == 0:
        return _cpr_nl_scalaire(float(lat))
    lat = np.asarray(lat, dtype=float)
    return np.array([_cpr_nl_scalaire(x) for x in lat.ravel()]).reshape(lat.shape)


def cpr_vers_lat_lon(LAT, LON, cprf, ref_lat, ref_lon):
    """cpr2LatLon : position la plus proche de la référence, rend (lon, lat).

    LAT, LON : entiers codés sur 17 bits ; cprf : 0 (trame paire) ou 1 (impaire).
    """
    i = cprf
    Dlat = 360 / (4 * NZ - i)
    j = np.floor(ref_lat / Dlat) + np.floor(0.5 + cpr_mod(ref_lat, Dlat) / Dlat - LAT / 2**NB)
    lat = Dlat * (j + LAT / 2**NB)

    nl = cpr_nl(lat)
    Dlon = 360 / (nl - i) if nl - i > 0 else 360
    m = np.floor(ref_lon / Dlon) + np.floor(0.5 + cpr_mod(ref_lon, Dlon) / Dlon - LON / 2**NB)
    lon = Dlon * (m + LON / 2**NB)

    # repli dans [-90, 270[ et [-180, 180[ comme en MATLAB
    if lat >= 270:
        lat = lat - 360
    if lon >= 180:
        lon = lon - 360
    return float(lon), float(lat)
