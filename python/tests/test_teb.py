"""TEB des tâches 1 et 4 recalculés en Python : mêmes réglages que le MATLAB,
autres tirages. On compare à la théorie et aux valeurs MATLAB à l'incertitude
statistique près (écart relatif d'un TEB compté sur n erreurs : environ 1/sqrt(n))."""

import numpy as np
import pytest

from adsb.teb import teb_non_coherent, teb_tache1, teb_tache4, teb_theorique
from conftest import charger


@pytest.fixture(scope="module")
def matlab():
    return charger("teb_matlab.mat")


def test_tache1(matlab):
    r = teb_tache1()
    assert np.array_equal(r["EbN0_dB"], matlab["t1_EbN0_dB"].ravel())
    assert (r["nb_err"] >= 200).all()
    assert np.max(np.abs(r["ber"] / teb_theorique(r["EbN0_dB"]) - 1)) < 0.25
    # écart à MATLAB : moins de 4 écarts types sur chaque point
    n_m = matlab["t1_nb_err"].ravel()
    ecart = np.abs(np.log(r["ber"] / matlab["t1_ber"].ravel())) / np.sqrt(1 / r["nb_err"] + 1 / n_m)
    assert ecart.max() < 4
    # l'ancienne règle par énergie fait environ deux fois plus d'erreurs
    assert (r["ber_energie"] > 1.5 * r["ber"]).all()


def test_tache4(matlab):
    r = teb_tache4()
    assert np.array_equal(r["EbN0_dB"], matlab["t4_EbN0_dB"].ravel())
    ok = r["err_parfait"] >= 100
    assert np.max(np.abs(r["ber_parfait"][ok] / teb_non_coherent(r["EbN0_dB"][ok]) - 1)) < 0.3
    assert abs(r["perte_decision"] - (r["x_nc"] - r["x_th"])) < 0.3
    assert abs(r["perte"] - float(matlab["t4_perte"].item())) < 0.15
