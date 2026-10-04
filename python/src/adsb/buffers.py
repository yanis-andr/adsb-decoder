"""Enregistrements réels (tâche 8) : portage de process_buffer.m et
update_liste_avion.m.

Les positions sont comptées à partir de 0 en Python, à partir de 1 en
MATLAB : position MATLAB = position + 1.
"""

from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import scipy.io as sio

from .crc import restes_lot
from .ppm import demoduler_ppm_lot, preambule
from .registres import Registre, bits_vers_registre
from .synchro import candidats, correlation_buffer

REF_LON = -0.606629   # ENSEIRB-Matmeca (antenne)
REF_LAT = 44.806884
SEUIL = 0.75          # valeur fournie avec le sujet (adsb_app) ; voir README.md
FICHIER_BUFFERS = Path(__file__).resolve().parents[3] / "data" / "buffers.mat"


@dataclass
class Message:
    buffer: int            # numéro du buffer, à partir de 1 comme en MATLAB
    position: int          # début du préambule dans le buffer (à partir de 0)
    correlation: float     # corrélation du préambule
    bits: np.ndarray       # 112 bits
    registre: Registre


def charger_buffers(fichier=FICHIER_BUFFERS):
    """Les 9 buffers complexes (une colonne par buffer) et la fréquence d'échantillonnage."""
    S = sio.loadmat(fichier)
    return S["buffers"], float(S["Rs"].item())


def decoder_candidats(y, k, Fse):
    """Bits (n x 112) et restes CRC (n x 24) des trames qui commencent après
    le préambule de chaque candidat k (démodulation et CRC en lot)."""
    Lp = 8 * Fse
    Ltrame = 112 * Fse
    indices = np.asarray(k)[:, None] + Lp + np.arange(Ltrame)
    bits = demoduler_ppm_lot(y[indices], Fse)
    return bits, restes_lot(bits)


def traiter_buffer(buffer_complexe, ref_lon=REF_LON, ref_lat=REF_LAT, seuil=SEUIL, Fse=4, numero=1):
    """process_buffer : rend les messages ADS-B (DF 17) à CRC bon du buffer.

    1) enveloppe |y| : la phase et le décalage en fréquence ne comptent plus ;
    2) corrélation normalisée avec le préambule, sur tout le buffer ;
    3) candidats : maxima locaux de la corrélation au-dessus du seuil ;
    4) pour chaque candidat : démodulation des 112 bits, CRC, registre.
    Seul DF 17 est gardé (un candidat placé un bit trop tôt peut passer le
    CRC, avec un DF inférieur à 16), et une trame identique qui chevauche la
    précédente est un doublon, gardé une seule fois.
    """
    y = np.abs(np.asarray(buffer_complexe).ravel())
    return traiter_enveloppe(y, ref_lon, ref_lat, seuil, Fse, numero)


def traiter_enveloppe(y, ref_lon=REF_LON, ref_lat=REF_LAT, seuil=SEUIL, Fse=4, numero=1):
    """Étapes 2 à 4 de traiter_buffer, sur l'enveloppe y déjà calculée."""
    p = preambule(Fse)
    Lp = len(p)
    Ltrame = 112 * Fse
    rho = correlation_buffer(y, p)
    k = candidats(rho, seuil, kmax=len(y) - Lp - Ltrame)

    bits, restes = decoder_candidats(y, k, Fse)
    messages = []
    derniers_bits = None
    fin_derniere = -1
    for i in np.flatnonzero(~restes.any(axis=1)):         # CRC bon
        registre = bits_vers_registre(bits[i], ref_lon, ref_lat)
        if registre.format != 17:
            continue
        if k[i] < fin_derniere and np.array_equal(bits[i], derniers_bits):
            continue                                      # doublon de la trame précédente
        messages.append(Message(numero, int(k[i]), float(rho[k[i]]), bits[i], registre))
        derniers_bits = bits[i]
        fin_derniere = k[i] + Lp + Ltrame
    return messages


def traiter_buffers(buffers, Fse=4, **options):
    """traiter_buffer sur chaque colonne ; numéros de buffer à partir de 1."""
    messages = []
    for b in range(buffers.shape[1]):
        messages += traiter_buffer(buffers[:, b], Fse=Fse, numero=b + 1, **options)
    return messages


@dataclass
class Avion:
    adresse: str
    indicatif: str | None = None
    messages: list = field(default_factory=list)
    # positions placées sur la carte : (buffer, lon, lat, altitude) ; comme
    # Avion.updateWithRegister, seuls les types 5 à 17 sont tracés
    trajectoire: list = field(default_factory=list)


def liste_avions(messages):
    """update_liste_avion : un avion par adresse, créé à sa première trame
    valide, dans l'ordre d'arrivée des messages."""
    avions = {}
    for m in messages:
        r = m.registre
        if r.erreur_crc or r.format != 17:
            continue
        avion = avions.setdefault(r.adresse, Avion(r.adresse))
        avion.messages.append(m)
        if r.type is not None and 1 <= r.type <= 4 and avion.indicatif is None and r.indicatif:
            avion.indicatif = r.indicatif
        elif r.type is not None and 5 <= r.type <= 17 and r.latitude is not None:
            avion.trajectoire.append((m.buffer, r.longitude, r.latitude, r.altitude))
    return list(avions.values())
