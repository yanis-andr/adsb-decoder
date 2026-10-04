"""Vecteurs de référence exportés par src/Tests/exporter_python.m.

Le dépôt public ne contient que blocs_synthetiques.mat : les vecteurs de
blocs.mat calculés sur des entrées tirées au hasard, sans les variables tirées
de adsb_msgs.mat (données du sujet). blocs.mat et buffers_reference.mat se
régénèrent avec MATLAB (voir README.md) ; s'ils sont là, ils sont utilisés.
Sans eux, les tests qui en ont besoin sont sautés, sauf avec
ADSB_EXIGER_DONNEES=1, où leur absence fait échouer les tests."""

import os
from pathlib import Path

import numpy as np
import pytest
import scipy.io as sio

DONNEES = Path(__file__).parent / "donnees"
FICHIER_BUFFERS = Path(__file__).resolve().parents[2] / "data" / "buffers.mat"
REGENERER = "regenerate it from the TS229 subject files, see README.md"


def manque(message):
    if os.environ.get("ADSB_EXIGER_DONNEES") == "1":
        pytest.fail(f"{message} (ADSB_EXIGER_DONNEES=1)")
    pytest.skip(message)


def charger(nom):
    if not (DONNEES / nom).exists():
        manque(f"tests/donnees/{nom} not found: {REGENERER}")
    S = sio.loadmat(DONNEES / nom)
    return {k: v for k, v in S.items() if not k.startswith("__")}


@pytest.fixture(scope="session")
def blocs():
    """blocs.mat complet s'il a été régénéré, sinon la partie synthétique."""
    if (DONNEES / "blocs.mat").exists():
        return charger("blocs.mat")
    return charger("blocs_synthetiques.mat")


@pytest.fixture(scope="session")
def blocs_registres(blocs):
    """Vecteurs de bit2registre (les 27 trames de adsb_msgs.mat et leurs variantes)."""
    if "adsb_msgs" not in blocs:
        manque(f"tests/donnees/blocs.mat (vectors built from adsb_msgs.mat) not found: {REGENERER}")
    return blocs


@pytest.fixture(scope="session")
def reference_buffers():
    return charger("buffers_reference.mat")


@pytest.fixture(scope="session")
def buffers():
    """Les 9 buffers (data/buffers.mat du sujet, hors git)."""
    if not FICHIER_BUFFERS.exists():
        manque("data/buffers.mat not found: download it from the TS229 subject repository, see README.md")
    from adsb.buffers import charger_buffers

    return charger_buffers(FICHIER_BUFFERS)


def champs_matlab(S, prefixe, i):
    """Champs du i-ème registre exporté (None pour un champ vide en MATLAB)."""
    nombre = lambda x: None if np.isnan(x) else x
    return {
        "format": int(S[f"{prefixe}_format"].ravel()[i]),
        "adresse": str(S[f"{prefixe}_adresse"][i]),
        "type": nombre(float(S[f"{prefixe}_type"].ravel()[i])),
        "indicatif": str(S[f"{prefixe}_planeName"][i]).ljust(8) if S[f"{prefixe}_a_indicatif"].ravel()[i] else None,
        "altitude": nombre(float(S[f"{prefixe}_altitude"].ravel()[i])),
        "cprf": nombre(float(S[f"{prefixe}_cprf"].ravel()[i])),
        "latitude": nombre(float(S[f"{prefixe}_latitude"].ravel()[i])),
        "longitude": nombre(float(S[f"{prefixe}_longitude"].ravel()[i])),
        "erreur_crc": int(S[f"{prefixe}_crcErrFlag"].ravel()[i]),
    }


def meme_registre(r, attendu, tol=0.0):
    """Mêmes champs que le registre MATLAB ; latitude et longitude à tol près (par défaut : égalité exacte)."""
    for c in ("format", "adresse", "type", "indicatif", "altitude", "cprf", "erreur_crc"):
        v = getattr(r, c)
        assert v == attendu[c], f"champ {c} : {v!r} au lieu de {attendu[c]!r}"
    for c in ("latitude", "longitude"):
        v, a = getattr(r, c), attendu[c]
        assert (v is None) == (a is None), f"champ {c} : {v!r} au lieu de {a!r}"
        if a is not None:
            assert abs(v - a) <= tol, f"champ {c} : écart {abs(v - a):.2e}"
