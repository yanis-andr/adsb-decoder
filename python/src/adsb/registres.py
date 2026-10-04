"""Couche MAC : 112 bits -> registre (tâche 6), portage de bit2registre.m.

Les champs suivent ceux du registre MATLAB (format, adresse, type,
planeName, altitude, cprf, latitude, longitude, crcErrFlag), en français :
indicatif = planeName, erreur_crc = crcErrFlag. Un champ vide en MATLAB vaut
None ici.

En plus du MATLAB : decoder_vitesse lit les messages de vitesse en vol
(FTC 19, tâche 7, optionnelle et hors du portage vérifié). Le registre en
garde le résultat dans vitesse_kt, cap_deg et taux_vertical_ft_min.
"""

from dataclasses import dataclass

import numpy as np

from .cpr import cpr_vers_lat_lon
from .crc import decoder_crc


@dataclass
class Registre:
    format: int
    adresse: str
    erreur_crc: int
    type: int | None = None
    indicatif: str | None = None
    altitude: int | None = None
    cprf: int | None = None
    latitude: float | None = None
    longitude: float | None = None
    vitesse_kt: float | None = None
    cap_deg: float | None = None
    taux_vertical_ft_min: int | None = None


def bits_vers_entier(bits):
    """bin2dec_custom : bits de poids fort en tête."""
    n = 0
    for b in bits:
        n = 2 * n + int(b)
    return n


def bits_vers_registre(bits, ref_lon, ref_lat):
    """bit2registre : le registre est toujours rendu, avec erreur_crc = 1 si le
    CRC échoue. Seules les trames ADS-B (DF 17) sont décodées : identification
    (FTC 1 à 4), position en vol (FTC 9 à 18) et, en plus du MATLAB, vitesse
    en vol (FTC 19)."""
    bits = np.asarray(bits, dtype=np.uint8).ravel()
    _, erreur = decoder_crc(bits)
    message = bits[:88]

    DF = bits_vers_entier(message[0:5])                    # Downlink Format
    adresse = f"{bits_vers_entier(message[8:32]):06X}"     # adresse OACI, 6 chiffres
    registre = Registre(format=DF, adresse=adresse, erreur_crc=erreur)
    if DF != 17:
        return registre

    data = message[32:88]                                  # 56 bits de données ADS-B
    FTC = bits_vers_entier(data[0:5])                      # Format Type Code
    registre.type = FTC

    if 1 <= FTC <= 4:                                      # identification
        registre.indicatif = decoder_indicatif(data)
    elif 9 <= FTC <= 18:                                   # position en vol
        registre.altitude = decoder_altitude(data[8:20])
        # data[20] : indicateur de temps UTC, non utilisé
        registre.cprf = int(data[21])
        LAT = bits_vers_entier(data[22:39])
        LON = bits_vers_entier(data[39:56])
        registre.longitude, registre.latitude = cpr_vers_lat_lon(LAT, LON, registre.cprf, ref_lat, ref_lon)
    elif FTC == 19:                                        # vitesse (hors MATLAB)
        registre.vitesse_kt, registre.cap_deg, registre.taux_vertical_ft_min = decoder_vitesse(data)
    return registre


def decoder_altitude(bits_altitude):
    """12 bits ; le 8e (bit Q) est ignoré, comme le dit le sujet ; pas de 25 ft."""
    ra = np.r_[bits_altitude[0:7], bits_altitude[8:12]]
    return 25 * bits_vers_entier(ra) - 1000


def _caractere(valeur):
    if 1 <= valeur <= 26:
        return chr(64 + valeur)       # A-Z
    if 48 <= valeur <= 57:
        return chr(valeur)            # 0-9
    if valeur == 32:
        return " "
    return "-"                        # code non défini


def decoder_indicatif(data):
    """8 caractères de 6 bits, espaces compris (comme la référence)."""
    return "".join(_caractere(bits_vers_entier(data[8 + 6 * k : 14 + 6 * k])) for k in range(8))


def decoder_vitesse(data):
    """FTC 19, sous-types 1 et 2 (vitesse sol) : rend (vitesse en kt, cap en
    degrés, taux vertical en ft/min) ; None quand l'information est absente.

    Champs (bits de data, à partir de 1) : sous-type 6-8, sens est-ouest 14,
    vitesse est-ouest 15-24, sens nord-sud 25, vitesse nord-sud 26-35, sens
    vertical 37, taux vertical 38-46. Une vitesse codée 0 est indisponible ;
    sinon elle vaut (code - 1) kt, fois 4 en sous-type 2 (supersonique).
    """
    sous_type = bits_vers_entier(data[5:8])
    if sous_type not in (1, 2):
        return None, None, None
    facteur = 4 if sous_type == 2 else 1
    v_eo = bits_vers_entier(data[14:24])
    v_ns = bits_vers_entier(data[25:35])
    vitesse = cap = None
    if v_eo > 0 and v_ns > 0:
        vx = (v_eo - 1) * facteur * (-1 if data[13] else 1)   # vers l'est
        vy = (v_ns - 1) * facteur * (-1 if data[24] else 1)   # vers le nord
        vitesse = float(np.hypot(vx, vy))
        cap = float(np.degrees(np.arctan2(vx, vy)) % 360)
    code_vertical = bits_vers_entier(data[37:46])
    taux = None
    if code_vertical > 0:
        taux = (code_vertical - 1) * 64 * (-1 if data[36] else 1)
    return vitesse, cap, taux
