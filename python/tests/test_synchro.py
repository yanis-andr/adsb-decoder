"""synchro contre shift_estimation (MATLAB), et corrélation des buffers."""

import numpy as np

from adsb.synchro import estimer_retard


def test_retard_identique(blocs):
    sp = blocs["synchro_sp"].ravel().astype(float)
    retard_max = int(blocs["synchro_retard_max"].item())
    ecart = 0.0
    for yl, estime, rho in zip(blocs["synchro_yl"], blocs["synchro_estime"].ravel(), blocs["synchro_rho"]):
        d, r = estimer_retard(yl, sp, retard_max)
        assert d == estime
        ecart = max(ecart, np.max(np.abs(r - rho)))
    assert ecart < 1e-12
    # les cinq premiers cas sont sans bruit : retard exact
    assert np.array_equal(blocs["synchro_estime"].ravel()[:5], blocs["synchro_retard"].ravel()[:5])


def test_retards_en_lot(blocs):
    """La version en lot (TEB de la tâche 4) donne les mêmes retards."""
    from adsb.synchro import estimer_retards_lot

    sp = blocs["synchro_sp"].ravel().astype(float)
    assert np.array_equal(estimer_retards_lot(blocs["synchro_yl"], sp, 100), blocs["synchro_estime"].ravel())
