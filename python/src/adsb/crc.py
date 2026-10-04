"""Code CRC-24 de l'ADS-B (tâche 3).

Portage de encodeCRC.m et decodeCRC.m : division polynomiale bit à bit,
écrite comme en MATLAB. Pour décoder beaucoup de trames d'un coup (buffers),
le CRC est linéaire : une trame w est valide si P·w[:88] + w[88:] = 0
modulo 2, où la colonne i de la matrice de parité P (24 x 88) est la parité
du i-ème vecteur unité (comme dans task8_seuil.m).
"""

import numpy as np

# g(x) = x^24 + x^23 + ... + x^13 + x^12 + x^10 + x^3 + 1
POLYNOME = np.array([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1], dtype=np.uint8)
DEGRE = len(POLYNOME) - 1   # 24 bits de CRC


def _diviser(mot):
    """Reste de la division de mot par le polynôme (les DEGRE derniers bits)."""
    reste = np.array(mot, dtype=np.uint8).ravel().copy()
    for i in range(len(reste) - DEGRE):
        if reste[i] == 1:
            reste[i : i + DEGRE + 1] ^= POLYNOME
    return reste[-DEGRE:]


def encoder_crc(bits):
    """encodeCRC : 88 bits -> 112 bits (message suivi du reste de x^24·m(x))."""
    bits = np.asarray(bits, dtype=np.uint8).ravel()
    reste = _diviser(np.r_[bits, np.zeros(DEGRE, dtype=np.uint8)])
    return np.r_[bits, reste]


def reste_crc(bits):
    """Reste de la division de la trame reçue (112 bits) : nul si la trame est intègre."""
    return _diviser(bits)


def decoder_crc(bits):
    """decodeCRC : rend les 88 bits du message et erreur = 1 si le reste est non nul."""
    bits = np.asarray(bits, dtype=np.uint8).ravel()
    erreur = int(reste_crc(bits).any())
    return bits[:-DEGRE], erreur


def matrice_parite():
    """Matrice P (24 x 88) : colonne i = parité de encoder_crc du i-ème vecteur unité."""
    P = np.zeros((DEGRE, 88), dtype=np.uint8)
    for i in range(88):
        e = np.zeros(88, dtype=np.uint8)
        e[i] = 1
        P[:, i] = encoder_crc(e)[88:]
    return P


_P = matrice_parite()


def restes_lot(trames):
    """Restes de plusieurs trames (une ligne de 112 bits par trame) : n x 24."""
    trames = np.asarray(trames, dtype=np.int64)
    return ((trames[:, :88] @ _P.T.astype(np.int64)) + trames[:, 88:]) % 2
