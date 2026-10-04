"""Durée couverte par les buffers : estimation par les vitesses annoncées (voir README.md)."""

import numpy as np

from adsb.buffers import traiter_buffers
from adsb.trajectoires import estimer_intervalles, premier_dernier


def test_intervalles(buffers):
    tampons, _ = buffers
    messages = traiter_buffers(tampons)
    intervalles, residu, segments = estimer_intervalles(messages)
    assert len(segments) == 47 and len({s["adresse"] for s in segments}) == 14
    assert np.array_equal(np.round(intervalles, 1), [10.3, 15.3, 15.7, 12.7, 10.1, 14.5, 14.6, 12.8])
    assert round(intervalles.sum()) == 106 and round(residu) == 5
    durees = [e["duree_s"] for e in premier_dernier(messages)]
    assert 97 < min(durees) and max(durees) < 115
