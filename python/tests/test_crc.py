"""crc contre encodeCRC et decodeCRC (MATLAB)."""

import numpy as np

from adsb.crc import decoder_crc, encoder_crc, matrice_parite, reste_crc, restes_lot


def test_codage_identique(blocs):
    for m, c in zip(blocs["crc_messages"], blocs["crc_codes"]):
        assert np.array_equal(encoder_crc(m), c)


def test_decodage_identique(blocs):
    for r, d, e, reste in zip(blocs["crc_recus"], blocs["crc_decodes"], blocs["crc_erreur"].ravel(), blocs["crc_reste"]):
        bits, erreur = decoder_crc(r)
        assert np.array_equal(bits, d) and erreur == e
        assert np.array_equal(reste_crc(r), reste)
    # 1 à 3 bits inversés : toujours détectés
    n_inv = np.arange(1, 301) % 4
    assert np.array_equal(blocs["crc_erreur"].ravel(), (n_inv > 0).astype(np.uint8))


def test_matrice_parite(blocs):
    assert np.array_equal(matrice_parite(), blocs["crc_parite"])
    assert np.array_equal(restes_lot(blocs["crc_recus"]), blocs["crc_reste"])
