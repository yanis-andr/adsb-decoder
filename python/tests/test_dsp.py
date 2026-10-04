"""dsp contre Mon_Welch (MATLAB)."""

import numpy as np

from adsb.dsp import mon_welch


def test_welch_identique(blocs):
    for x, Fe, n in (("welch_x1", 20e6, 1), ("welch_x2", 4e6, 2)):
        y, f = mon_welch(blocs[x].ravel(), 256, Fe)
        attendu = blocs[f"welch_y{n}"].ravel()
        assert np.max(np.abs(y - attendu) / np.max(attendu)) < 1e-12
        assert np.allclose(f, blocs[f"welch_f{n}"].ravel(), rtol=0, atol=1e-6)
