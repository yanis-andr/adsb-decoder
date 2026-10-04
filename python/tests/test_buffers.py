"""buffers contre process_buffer (MATLAB) sur les 9 enregistrements :
mêmes candidats, mêmes 171 messages aux mêmes positions, mêmes champs."""

import numpy as np
import pytest

from adsb.buffers import decoder_candidats, liste_avions, traiter_buffers
from adsb.crc import restes_lot
from adsb.ppm import preambule
from adsb.registres import bits_vers_registre
from adsb.synchro import candidats, correlation_buffer
from conftest import champs_matlab, meme_registre


@pytest.fixture(scope="module")
def messages(buffers):
    tampons, Rs = buffers
    return traiter_buffers(tampons, Fse=int(Rs / 1e6))


def test_candidats_identiques(buffers, reference_buffers):
    """Étapes 2 et 3 de process_buffer : mêmes maxima locaux, même
    corrélation (à 1e-12 près), mêmes bits et même CRC."""
    R = reference_buffers
    tampons, _ = buffers
    p = preambule(4)
    for b in range(tampons.shape[1]):
        y = np.abs(tampons[:, b])
        rho = correlation_buffer(y, p)
        assert (rho >= 0.75).sum() == R["nb_au_dessus_seuil"].ravel()[b]
        k = candidats(rho, 0.75, kmax=len(y) - 32 - 448)
        sel = R["cand_buf"].ravel() == b + 1
        assert np.array_equal(k + 1, R["cand_pos"].ravel()[sel])          # MATLAB compte à partir de 1
        assert np.max(np.abs(rho[k] - R["cand_rho"].ravel()[sel])) < 1e-12
        bits, restes = decoder_candidats(y, k, 4)
        assert np.array_equal(bits, R["cand_bits"][sel])
        assert np.array_equal(restes.any(axis=1), R["cand_erreur"].ravel()[sel].astype(bool))


def test_171_messages_identiques(messages, reference_buffers):
    R = reference_buffers
    assert len(messages) == 171
    assert [m.buffer for m in messages] == R["msg_buf"].ravel().tolist()
    assert [m.position + 1 for m in messages] == R["msg_pos"].ravel().tolist()
    assert np.max(np.abs(np.array([m.correlation for m in messages]) - R["msg_corr"].ravel())) < 1e-12
    for i, m in enumerate(messages):
        assert np.array_equal(m.bits, R["msg_bits"][i])
        meme_registre(m.registre, champs_matlab(R, "msg", i))


def test_comptes(messages):
    """163 contenus distincts, 26 avions, 75 positions
    dont 70 tracées (FTC 18 non tracé, comme Avion.updateWithRegister)."""
    assert len({m.bits.tobytes() for m in messages}) == 163
    assert sum(m.registre.latitude is not None for m in messages) == 75
    avions = liste_avions(messages)
    assert len(avions) == 26
    assert sum(len(a.trajectoire) for a in avions) == 70
    types = {}
    for m in messages:
        types[m.registre.type] = types.get(m.registre.type, 0) + 1
    assert types == {4: 6, 11: 66, 12: 4, 18: 5, 19: 76, 28: 2, 29: 9, 31: 3}


def test_enveloppe_par_racine(buffers, messages):
    """Le navigateur calcule l'enveloppe par sqrt(i² + q²), qui diffère parfois
    de |y| (hypot) au dernier bit près : les 171 messages restent les mêmes."""
    from adsb.buffers import traiter_enveloppe

    tampons, _ = buffers
    autres = []
    for b in range(tampons.shape[1]):
        i, q = tampons[:, b].real, tampons[:, b].imag
        autres += traiter_enveloppe(np.sqrt(i * i + q * q), numero=b + 1)
    assert [(m.buffer, m.position, m.bits.tobytes()) for m in autres] == [
        (m.buffer, m.position, m.bits.tobytes()) for m in messages
    ]


def test_constantes_de_la_reference(messages):
    """Les chiffres de la chaîne de l'enseignant recopiés dans l'export
    (portfolio.REFERENCE_ENSEIGNANT) s'accordent avec notre décodage : ses
    trames distinctes sont nos trames des types qu'elle décode (4, 11, 12),
    ses positions distinctes nos positions tracées, ses doublons tous en FTC 11,
    et ses 23 avions plus les 3 absents font nos 26."""
    from adsb.portfolio import AVIONS_ABSENTS_DE_LA_REFERENCE, NOTES_AVIONS, REFERENCE_ENSEIGNANT as R

    types = [m.registre.type for m in messages]
    assert sum(t in (4, 11, 12) for t in types) == R["trames_distinctes"]
    assert R["trames_distinctes"] + R["doublons"] == R["messages_valides"]
    assert {k: types.count(int(k)) for k in R["par_type"]} == {"4": 6, "11": 83 - R["doublons"], "12": 4}
    avions = liste_avions(messages)
    assert sum(len(a.trajectoire) for a in avions) == R["positions_distinctes"]
    assert R["positions_distinctes"] + R["doublons"] == R["positions"]
    adresses = {a.adresse for a in avions}
    assert AVIONS_ABSENTS_DE_LA_REFERENCE <= adresses
    assert len(adresses - AVIONS_ABSENTS_DE_LA_REFERENCE) == R["avions"] == 23
    # avions d'une seule trame : 4, dont les deux commentés
    seuls = {a.adresse for a in avions if len(a.messages) == 1}
    assert seuls == {"398446", "405636", "39D702", "471F7D"} and set(NOTES_AVIONS) <= seuls
