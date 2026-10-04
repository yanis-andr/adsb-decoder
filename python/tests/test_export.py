"""L'export (export/adsb-portfolio.json, écrit par python -m adsb.etude) a la
forme décrite dans python/README.md : clés et types du premier niveau et d'un
élément de chaque liste. Il contient des extraits des enregistrements : il
n'est pas versionné, ces tests sont sautés tant qu'il n'a pas été produit."""

import json
from pathlib import Path

import pytest

from conftest import manque

EXPORT = Path(__file__).resolve().parents[1] / "export" / "adsb-portfolio.json"
N = (int, float)


@pytest.fixture(scope="module")
def export():
    if not EXPORT.exists():
        manque("export/adsb-portfolio.json not found: run `uv run python -m adsb.etude` (needs data/buffers.mat)")
    return json.loads(EXPORT.read_text())


def verifier(objet, forme):
    assert set(objet) == set(forme), f"clés {sorted(set(objet) ^ set(forme))}"
    for k, t in forme.items():
        assert isinstance(objet[k], t), f"{k} : {type(objet[k]).__name__}"


def test_premier_niveau(export):
    verifier(export, {
        "version": int, "source": dict, "parametres": dict, "trames_exemples": list, "messages": list,
        "avions": list, "chiffres": dict, "comparaison_reference": dict, "seuil": dict, "duree": dict,
        "teb": dict, "dsp": dict,
    })
    verifier(export["parametres"], {
        "Fe_Hz": int, "Rb_bit_s": int, "Fse": int, "echantillons_par_buffer": int, "nb_buffers": int,
        "seuil": float, "reference": dict, "preambule": list, "polynome_crc": str, "positions": str,
    })
    verifier(export["chiffres"], {
        "messages": int, "contenus_distincts": int, "avions": int, "positions": int,
        "positions_tracees": int, "par_type": dict,
    })
    verifier(export["duree"], {
        "est_une_estimation": bool, "base": str, "segments": int, "avions": int, "intervalles_s": list,
        "total_s": float, "residu_rms_s": float, "avions_vus_aux_buffers_1_et_9": list, "fourchette": str,
        "signal_enregistre_s": float,
    })
    assert set(export["teb"]) == {"tache1", "tache4"}


def test_elements_des_listes(export):
    t = export["trames_exemples"][0]
    verifier(t, {
        "categorie": str, "buffer": int, "position": int, "t_buffer_us": float, "correlation": float,
        "hex": str, "fenetre": dict, "decision": dict, "bits": str, "crc": dict, "segments": list,
        "champs": dict, "variante_bruitee": dict,
    })
    verifier(t["fenetre"], {
        "debut": int, "i": list, "q": list, "enveloppe": list, "correlation": list,
        "position_preambule": int, "debut_donnees": int,
    })
    verifier(t["decision"], {"regle": str, "instants_r1": list, "instants_r2": list, "r1": list, "r2": list})
    verifier(t["crc"], {"recu": str, "calcule": str, "reste": str, "valide": bool})
    verifier(t["segments"][0], {"nom": str, "debut": int, "fin": int})
    verifier(t["variante_bruitee"], {"signal_propre": list, "debut_donnees": int, "modele": dict, "theorie": list})
    verifier(t["variante_bruitee"]["theorie"][0], {"EbN0_dB": float, "teb": float, "p_trame_intacte": float})
    m = export["messages"][0]
    for k, typ in {"buffer": int, "position": int, "correlation": float, "hex": str, "df": int, "ca": int,
                   "adresse": str, "ftc": int}.items():
        assert isinstance(m[k], typ)
    a = export["avions"][0]
    verifier(a, {
        "adresse": str, "indicatif": (str, type(None)), "nb_messages": int, "par_type": dict, "buffers": list,
        "dans_reference": bool, "une_seule_trame": bool, "note": (str, type(None)), "positions": list,
        "vitesse": (dict, type(None)),
    })
    verifier(a["positions"][0], {
        "buffer": int, "position": int, "ftc": int, "latitude": float, "longitude": float,
        "altitude_ft": int, "cprf": int, "tracee": bool,
    })
    verifier(export["duree"]["avions_vus_aux_buffers_1_et_9"][0],
             {"adresse": str, "distance_km": float, "vitesse_kt": float, "duree_s": float})
    d = export["dsp"]
    assert len(d["f_MHz"]) == len(d["estimee_dB"]) == 256 and d["nb_fft"] == 2000
    for courbe in ("tache1", "tache4"):
        assert isinstance(export["teb"][courbe]["EbN0_dB"][0], N)


def test_avions_d_une_seule_trame(export):
    seuls = {a["adresse"]: a["note"] for a in export["avions"] if a["une_seule_trame"]}
    assert set(seuls) == {"398446", "405636", "39D702", "471F7D"}
    assert seuls["398446"] and seuls["405636"] and seuls["39D702"] is None
    assert all(a["une_seule_trame"] == (a["nb_messages"] == 1) for a in export["avions"])
