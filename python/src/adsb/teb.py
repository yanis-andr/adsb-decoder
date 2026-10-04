"""Taux d'erreur binaire simulés (tâches 1 et 4), recalculés en Python.

Mêmes réglages et mêmes règles d'arrêt que test_task1_ber.m et
test_task4_ber_sync.m ; seuls les tirages diffèrent (générateur numpy au
lieu de celui de MATLAB), d'où des écarts de l'ordre de l'incertitude
statistique (environ 1/sqrt(nombre d'erreurs)).
"""

import numpy as np
from scipy.special import erfc, erfcinv

from .ppm import moduler_ppm, preambule
from .synchro import estimer_retards_lot


def teb_theorique(EbN0_dB):
    """Tâche 1 (ST7) : Pb = 0,5·erfc(sqrt(Eb/2N0)) ; décision r1 > r2 sur bruit réel."""
    return 0.5 * erfc(np.sqrt(10 ** (np.asarray(EbN0_dB) / 10) / 2))


def teb_non_coherent(EbN0_dB):
    """Tâche 4 : Pb = 0,5·exp(-Eb/2N0) ; décision |r1| > |r2| (phase inconnue)."""
    return 0.5 * np.exp(-(10 ** (np.asarray(EbN0_dB) / 10)) / 2)


def premier_arret(erreurs_cumulees, debut, condition):
    """Indice (dans le lot) du premier paquet après lequel la boucle s'arrête, ou None."""
    n = debut + np.arange(1, len(erreurs_cumulees) + 1)
    ok = np.flatnonzero(condition(erreurs_cumulees, n))
    return int(ok[0]) if len(ok) else None


def teb_tache1(EbN0_dB=np.arange(11), Fse=20, Nb=1000, min_erreurs=200, graine=11, lot=50):
    """Tâche 1 ST6 : paquets de Nb bits jusqu'à min_erreurs erreurs par point.
    Bruit réel de variance N0/2 par échantillon, Eb = Fse/2 (énergie de p1).
    Rend, pour chaque point, le TEB de r1 > r2, le nombre d'erreurs et le TEB
    de l'ancienne règle par énergie |r1|² > |r2|² (même signal reçu)."""
    rng = np.random.default_rng(graine)
    Eb = Fse / 2
    ber, nb_err, ber_energie = [], [], []
    for x in EbN0_dB:
        N0 = Eb / 10 ** (x / 10)
        erreurs = erreurs_e = bits = 0
        while erreurs < min_erreurs:
            b = rng.integers(0, 2, (lot, Nb))
            s = moduler_ppm(b.ravel(), Fse).reshape(lot, Nb * Fse)
            r = s + np.sqrt(N0 / 2) * rng.standard_normal(s.shape)
            R = r.reshape(lot, Nb, Fse)
            r1 = R[:, :, : Fse // 2].sum(axis=2)
            r2 = R[:, :, Fse // 2 :].sum(axis=2)
            e = (b != (r1 > r2)).sum(axis=1)                       # erreurs par paquet
            e_energie = (b != (r1**2 > r2**2)).sum(axis=1)
            # la boucle MATLAB s'arrête au premier paquet qui atteint min_erreurs
            fin = premier_arret(erreurs + np.cumsum(e), 0, lambda c, n: c >= min_erreurs)
            garde = lot if fin is None else fin + 1
            erreurs += int(e[:garde].sum())
            erreurs_e += int(e_energie[:garde].sum())
            bits += garde * Nb
        ber.append(erreurs / bits)
        nb_err.append(erreurs)
        ber_energie.append(erreurs_e / bits)
    return {
        "EbN0_dB": np.asarray(EbN0_dB, dtype=float),
        "ber": np.array(ber),
        "nb_err": np.array(nb_err),
        "ber_energie": np.array(ber_energie),
        "Pb_th": teb_theorique(EbN0_dB),
    }


def teb_tache4(EbN0_dB=np.r_[np.arange(10), np.arange(9.5, 12.01, 0.5), 13, 14], graine=47, lot=1000,
               min_erreurs=300, min_trames=3000, max_trames=30000):
    """Tâche 4 ST7 : trames de 112 bits précédées du préambule (Fse = 20),
    retard sur [0, 100 Te], décalage de fréquence sur [-1, 1] kHz, phase sur
    [0, 2π], bruit complexe de variance N0/2 par voie. Chaque trame est
    démodulée (|r1| > |r2|) au retard estimé et au vrai retard."""
    rng = np.random.default_rng(graine)
    Fe, Fse, retard_max, Nbits = 20e6, 20, 100, 112
    sp = preambule(Fse)
    Lp = len(sp)
    L = Lp + Nbits * Fse + retard_max
    Eb = Fse / 2
    t = np.arange(L) / Fe
    lignes = np.arange(lot)[:, None]
    res = {k: [] for k in ("ber_sync", "ber_parfait", "err_sync", "err_parfait", "trames", "mal_calees")}
    for x in EbN0_dB:
        N0 = Eb / 10 ** (x / 10)
        err = err_p = trames = mal = 0
        while (err < min_erreurs or trames < min_trames) and trames < max_trames:
            b = rng.integers(0, 2, (lot, Nbits))
            sl = np.c_[np.tile(sp, (lot, 1)), moduler_ppm(b.ravel(), Fse).reshape(lot, -1)]
            retard = rng.integers(0, retard_max + 1, lot)
            df = (rng.random(lot) - 0.5) * 2e3
            phi0 = rng.random(lot) * 2 * np.pi
            sl_tx = np.zeros((lot, L))
            colonnes = retard[:, None] + np.arange(sl.shape[1])
            sl_tx[lignes, colonnes] = sl
            yl = sl_tx * np.exp(-1j * 2 * np.pi * df[:, None] * t + 1j * phi0[:, None])
            yl += np.sqrt(N0 / 2) * (rng.standard_normal((lot, L)) + 1j * rng.standard_normal((lot, L)))

            estime = estimer_retards_lot(yl, sp, retard_max)
            erreurs = []
            for d in (estime, retard):
                donnees = yl[lignes, d[:, None] + Lp + np.arange(Nbits * Fse)].reshape(lot, Nbits, Fse)
                r1 = donnees[:, :, : Fse // 2].sum(axis=2)
                r2 = donnees[:, :, Fse // 2 :].sum(axis=2)
                erreurs.append((b != (np.abs(r1) > np.abs(r2))).sum(axis=1))
            e, e_p = erreurs
            # même règle d'arrêt que la boucle MATLAB, trame par trame
            fin = premier_arret(
                err + np.cumsum(e), trames,
                lambda c, n: ((c >= min_erreurs) & (n >= min_trames)) | (n >= max_trames),
            )
            garde = lot if fin is None else fin + 1
            err += int(e[:garde].sum())
            err_p += int(e_p[:garde].sum())
            mal += int((estime[:garde] != retard[:garde]).sum())
            trames += garde
        res["ber_sync"].append(err / (trames * Nbits))
        res["ber_parfait"].append(err_p / (trames * Nbits))
        res["err_sync"].append(err)
        res["err_parfait"].append(err_p)
        res["trames"].append(trames)
        res["mal_calees"].append(mal / trames)
    res = {k: np.array(v) for k, v in res.items()}
    res["EbN0_dB"] = np.asarray(EbN0_dB, dtype=float)
    res.update(seuils_1e3(res["EbN0_dB"], res["ber_sync"], res["err_sync"], res["ber_parfait"], res["err_parfait"]))
    return res


def croisement(EbN0_dB, ber, nb_err, cible=1e-3):
    """Eb/N0 où le TEB passe sous la cible (interpolation en log du TEB),
    entre deux points d'au moins 100 erreurs ; NaN sinon."""
    for i in range(len(ber) - 1):
        if ber[i] >= cible > ber[i + 1] and nb_err[i] >= 100 and nb_err[i + 1] >= 100:
            a, c = np.log10(ber[i]), np.log10(ber[i + 1])
            return float(EbN0_dB[i] + (EbN0_dB[i + 1] - EbN0_dB[i]) * (np.log10(cible) - a) / (c - a))
    return float("nan")


def seuils_1e3(EbN0_dB, ber_sync, err_sync, ber_parfait, err_parfait, cible=1e-3):
    """Perte à TEB = 1e-3 : totale (retard estimé contre la théorie de la
    tâche 1), décomposée en décision non cohérente et synchronisation."""
    x_th = 10 * np.log10(2 * erfcinv(2 * cible) ** 2)
    x_nc = 10 * np.log10(2 * np.log(0.5 / cible))
    x_sync = croisement(EbN0_dB, ber_sync, err_sync, cible)
    x_parfait = croisement(EbN0_dB, ber_parfait, err_parfait, cible)
    return {
        "x_th": float(x_th), "x_nc": float(x_nc), "x_sync": x_sync, "x_parfait": x_parfait,
        "perte": x_sync - x_th, "perte_decision": x_parfait - x_th, "perte_synchro": x_sync - x_parfait,
    }
