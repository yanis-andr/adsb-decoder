"""cpr contre cprNL, cprMod et cpr2LatLon (MATLAB)."""

import numpy as np

from adsb.cpr import cpr_mod, cpr_nl, cpr_vers_lat_lon


def test_nl_identique(blocs):
    lat = blocs["cpr_nl_lat"].ravel()
    assert np.array_equal(cpr_nl(lat), blocs["cpr_nl"].ravel())
    assert cpr_nl(87) == 2 and cpr_nl(-87) == 2 and cpr_nl(0) == 59


def test_mod_identique(blocs):
    a, b = blocs["cpr_mod_a"].ravel(), blocs["cpr_mod_b"].ravel().astype(float)
    assert np.array_equal(cpr_mod(a, b), blocs["cpr_mod"].ravel())


def test_lat_lon_identiques(blocs):
    ecart = 0.0
    for k in range(len(blocs["cpr_LAT"])):
        lon, lat = cpr_vers_lat_lon(
            int(blocs["cpr_LAT"][k, 0]), int(blocs["cpr_LON"][k, 0]), int(blocs["cpr_cprf"][k, 0]),
            float(blocs["cpr_refLat"][k, 0]), float(blocs["cpr_refLon"][k, 0]),
        )
        ecart = max(ecart, abs(lat - blocs["cpr_lat"][k, 0]), abs(lon - blocs["cpr_lon"][k, 0]))
    assert ecart == 0.0
