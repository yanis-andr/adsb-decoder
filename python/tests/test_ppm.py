"""ppm contre modulatePPM, get_preamble, preambule et demodulatePPM (MATLAB)."""

import numpy as np
import pytest

from adsb.ppm import demoduler_ppm, demoduler_ppm_lot, moduler_ppm, preambule


@pytest.mark.parametrize("Fse", [4, 20])
def test_modulation_identique(blocs, Fse):
    for symboles, attendu in zip(blocs["ppm_symboles"], blocs[f"ppm_module_{Fse}"]):
        assert np.array_equal(moduler_ppm(symboles.astype(int), Fse), attendu)


@pytest.mark.parametrize("Fse", [4, 20])
def test_preambule_identique(blocs, Fse):
    assert np.array_equal(preambule(Fse), blocs[f"preambule_{Fse}"].ravel())


def test_preambule_tache4(blocs):
    assert np.array_equal(preambule(20), blocs["preambule_tache4_20"].ravel())


@pytest.mark.parametrize("Fse", [4, 20])
def test_demodulation_reelle_identique(blocs, Fse):
    """Sans bruit, bruité, et égalités r1 = r2 (décision 0) : mêmes bits."""
    signaux = blocs[f"demod_reel_{Fse}"].astype(float)
    attendus = blocs[f"demod_reel_sortie_{Fse}"]
    for r, attendu in zip(signaux, attendus):
        assert np.array_equal(demoduler_ppm(r, Fse), attendu)
    assert np.array_equal(demoduler_ppm_lot(signaux, Fse), attendus)
    # les quatre premiers sont sans bruit : bits émis retrouvés
    assert np.array_equal(attendus[:4], blocs[f"demod_bits_{Fse}"][:4])
    # égalités : tout à 0, sauf le premier bit du dernier cas
    assert not attendus[-3:-1].any() and attendus[-1, 0] == 1 and not attendus[-1, 1:].any()


@pytest.mark.parametrize("Fse", [4, 20])
def test_demodulation_complexe_identique(blocs, Fse):
    for r, attendu in zip(blocs[f"demod_cplx_{Fse}"], blocs[f"demod_cplx_sortie_{Fse}"]):
        assert np.array_equal(demoduler_ppm(r, Fse), attendu)


def test_aller_retour():
    b = np.random.default_rng(1).integers(0, 2, 112)
    assert np.array_equal(demoduler_ppm(moduler_ppm(b, 4), 4), b)
