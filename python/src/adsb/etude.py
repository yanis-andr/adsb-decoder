"""Rejoue tout le portage et écrit l'export du portfolio.

    uv run python -m adsb.etude

1) décode les 9 buffers de data/buffers.mat (171 messages, 26 avions) ;
2) recalcule les TEB des tâches 1 et 4 et les compare aux valeurs MATLAB
   (tests/donnees/teb_matlab.mat) et à la théorie ;
3) estime la durée couverte par les buffers ;
4) écrit export/adsb-portfolio.json et affiche un résumé.
"""

import json
import time
from pathlib import Path

import numpy as np
import scipy.io as sio

from . import buffers as bf
from .portfolio import construire
from .teb import teb_tache1, teb_tache4

RACINE = Path(__file__).resolve().parents[2]          # dossier python/
EXPORT = RACINE / "export" / "adsb-portfolio.json"
TEB_MATLAB = RACINE / "tests" / "donnees" / "teb_matlab.mat"


def en_json(x):
    """Types numpy -> types Python pour json."""
    if isinstance(x, np.integer):
        return int(x)
    if isinstance(x, np.floating):
        return float(x)
    if isinstance(x, np.bool_):
        return bool(x)
    if isinstance(x, np.ndarray):
        return x.tolist()
    raise TypeError(type(x))


def main():
    t0 = time.perf_counter()
    if not bf.FICHIER_BUFFERS.exists():
        raise SystemExit(f"{bf.FICHIER_BUFFERS} absent : les enregistrements du sujet sont nécessaires")
    tampons, Rs = bf.charger_buffers()
    Fse = round(Rs / 1e6)
    messages = bf.traiter_buffers(tampons, Fse=Fse)
    avions = bf.liste_avions(messages)
    t_decodage = time.perf_counter() - t0

    t1 = teb_tache1()
    t4 = teb_tache4()
    matlab = {k: v for k, v in sio.loadmat(TEB_MATLAB).items() if not k.startswith("__")}

    export = construire(messages, avions, tampons, t1, t4, matlab, Fse=Fse, Rs=Rs)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    EXPORT.write_text(json.dumps(export, ensure_ascii=False, separators=(",", ":"), default=en_json) + "\n")

    c = export["chiffres"]
    d = export["duree"]
    s = export["teb"]["tache4"]["seuil_1e3"]
    i10 = int(np.flatnonzero(t1["EbN0_dB"] == 10)[0])
    print(f"Buffers : {c['messages']} messages DF 17 ({c['contenus_distincts']} contenus distincts), "
          f"{c['avions']} avions, {c['positions']} positions dont {c['positions_tracees']} tracées "
          f"({t_decodage:.1f} s)")
    print(f"Tâche 1 : TEB à 10 dB = {t1['ber'][i10]:.2e} (MATLAB {matlab['t1_ber'].ravel()[i10]:.2e}, "
          f"théorie {t1['Pb_th'][i10]:.2e})")
    print(f"Tâche 4 : 1e-3 à {s['python']['x_sync']:.2f} dB (MATLAB {s['matlab']['x_sync']:.2f}, "
          f"théorie {s['theorie_coherente_dB']:.2f}) ; perte {s['python']['perte']:.2f} dB "
          f"(MATLAB {s['matlab']['perte']:.2f}) = {s['python']['perte_decision']:.2f} dB de décision non cohérente "
          f"+ {s['python']['perte_synchro']:.2f} dB de synchronisation")
    print(f"Durée estimée : {d['total_s']:.0f} s du buffer 1 au buffer 9 ({d['segments']} segments, "
          f"{d['avions']} avions, résidu {d['residu_rms_s']:.0f} s)")
    print(f"Export : {EXPORT.relative_to(RACINE)} ({EXPORT.stat().st_size / 1024:.0f} Kio), "
          f"{len(export['trames_exemples'])} trames pas à pas, {len(export['messages'])} messages, "
          f"{len(export['avions'])} avions ({time.perf_counter() - t0:.0f} s en tout)")


if __name__ == "__main__":
    main()
