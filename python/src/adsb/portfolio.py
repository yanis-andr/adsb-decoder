"""Export JSON pour la page du portfolio (forme décrite dans python/README.md).

Tout ce qui est écrit ici est calculé par le portage, sauf les chiffres de
la chaîne de l'enseignant (fonctions .p, non portées), recopiés de
README.md et signalés comme tels.
"""

import numpy as np

from . import buffers as bf
from .crc import POLYNOME, encoder_crc, reste_crc
from .dsp import dsp_analytique, mon_welch
from .ppm import moduler_ppm, preambule
from .registres import bits_vers_entier
from .synchro import correlation_buffer
from .teb import teb_theorique
from .trajectoires import estimer_intervalles, premier_dernier

MARGE = 40          # échantillons montrés avant le préambule et après la trame
VERSION = 1

# Chaîne de l'enseignant (fonctions .p), mesurée par src/Tests/task8.m
REFERENCE_ENSEIGNANT = {
    "registres_rendus": 152,
    "messages_valides": 93,
    "doublons": 17,
    "trames_distinctes": 76,
    "positions": 87,
    "positions_distinctes": 70,
    "avions": 23,
    "par_type": {"4": 6, "11": 83, "12": 4},
}
AVIONS_ABSENTS_DE_LA_REFERENCE = {"3444C3", "405636", "398446"}
# avions vus sur une seule trame : ce qu'en dit README.md
NOTES_AVIONS = {
    "398446": "une seule trame (vitesse, FTC 19), dont les champs de vitesse sont tous à 0 (information "
              "indisponible) ; aucune autre trame de cette adresse, même en descendant le seuil à 0,5",
    "405636": "une seule trame au-dessus du seuil (vitesse, FTC 19 : 351 kt, cap 168°, descente de 1 536 ft/min), "
              "corroborée par une position lue juste sous le seuil (buffer 5, corrélation 0,623, CRC bon) à "
              "22 825 ft, cohérente avec la descente annoncée",
}


def chaine_bits(bits):
    return "".join(str(int(b)) for b in bits)


def hexa(bits):
    return f"{bits_vers_entier(bits):028X}"


def arrondi(x, n):
    return None if x is None else round(float(x), n)


# ---------------------------------------------------------------- trames pas à pas

def segments_trame(ftc):
    """Champs de la trame, en bits (début inclus, fin exclue, à partir de 0)."""
    s = [
        {"nom": "DF", "debut": 0, "fin": 5},
        {"nom": "CA", "debut": 5, "fin": 8},
        {"nom": "adresse", "debut": 8, "fin": 32},
        {"nom": "FTC", "debut": 32, "fin": 37},
    ]
    if 1 <= ftc <= 4:
        s += [{"nom": "categorie", "debut": 37, "fin": 40}]
        s += [{"nom": f"caractere_{k + 1}", "debut": 40 + 6 * k, "fin": 46 + 6 * k} for k in range(8)]
    elif 9 <= ftc <= 18:
        s += [
            {"nom": "surveillance", "debut": 37, "fin": 39},
            {"nom": "nic_supplement", "debut": 39, "fin": 40},
            {"nom": "altitude", "debut": 40, "fin": 52},
            {"nom": "temps_utc", "debut": 52, "fin": 53},
            {"nom": "cprf", "debut": 53, "fin": 54},
            {"nom": "lat_cpr", "debut": 54, "fin": 71},
            {"nom": "lon_cpr", "debut": 71, "fin": 88},
        ]
    elif ftc == 19:
        s += [
            {"nom": "sous_type", "debut": 37, "fin": 40},
            {"nom": "sens_est_ouest", "debut": 45, "fin": 46},
            {"nom": "vitesse_est_ouest", "debut": 46, "fin": 56},
            {"nom": "sens_nord_sud", "debut": 56, "fin": 57},
            {"nom": "vitesse_nord_sud", "debut": 57, "fin": 67},
            {"nom": "sens_vertical", "debut": 68, "fin": 69},
            {"nom": "taux_vertical", "debut": 69, "fin": 78},
        ]
    s.append({"nom": "crc", "debut": 88, "fin": 112})
    return s


def champs_registre(m):
    r = m.registre
    data = m.bits[32:88]
    c = {
        "df": r.format,
        "ca": bits_vers_entier(m.bits[5:8]),
        "adresse": r.adresse,
        "ftc": r.type,
    }
    if r.indicatif is not None:
        c["indicatif"] = r.indicatif
    if r.latitude is not None:
        c.update(
            altitude_ft=r.altitude, cprf=r.cprf,
            lat_cpr=bits_vers_entier(data[22:39]), lon_cpr=bits_vers_entier(data[39:56]),
            latitude=r.latitude, longitude=r.longitude,
        )
    if r.type == 19:
        c.update(
            sous_type=bits_vers_entier(data[5:8]),
            vitesse_kt=arrondi(r.vitesse_kt, 1), cap_deg=arrondi(r.cap_deg, 1),
            taux_vertical_ft_min=r.taux_vertical_ft_min,
        )
    return c


def trame_pas_a_pas(m, tampon, categorie, Fse=4):
    """Étapes d'une trame réelle : enveloppe, corrélation, décision, bits, CRC, champs."""
    Lp, Ltrame = 8 * Fse, 112 * Fse
    debut = max(m.position - MARGE, 0)
    fin = min(m.position + Lp + Ltrame + MARGE, len(tampon))
    i = tampon.real[debut:fin].astype(int)
    q = tampon.imag[debut:fin].astype(int)
    y = np.sqrt(i * i + q * q)
    # corrélation pour chaque début de fenêtre de 32 échantillons
    rho = correlation_buffer(np.sqrt(tampon.real[debut : fin + Lp] ** 2 + tampon.imag[debut : fin + Lp] ** 2),
                             preambule(Fse))[: fin - debut]
    debut_donnees = m.position - debut + Lp
    instants_r1 = [[debut_donnees + Fse * k + j for j in range(Fse // 2)] for k in range(112)]
    instants_r2 = [[debut_donnees + Fse * k + j for j in range(Fse // 2, Fse)] for k in range(112)]
    r1 = [float(y[a].sum()) for a in instants_r1]
    r2 = [float(y[a].sum()) for a in instants_r2]
    bits = (np.array(r1) > np.array(r2)).astype(np.uint8)
    assert np.array_equal(bits, m.bits), "décision relue différente"
    reste = reste_crc(m.bits)
    return {
        "categorie": categorie,
        "buffer": m.buffer,
        "position": m.position + 1,
        "t_buffer_us": m.position / Fse,
        "correlation": m.correlation,
        "hex": hexa(m.bits),
        "fenetre": {
            "debut": debut + 1,
            "i": i.tolist(),
            "q": q.tolist(),
            "enveloppe": [round(float(v), 3) for v in y],
            "correlation": [round(float(v), 4) for v in rho],
            "position_preambule": m.position - debut,
            "debut_donnees": int(debut_donnees),
        },
        "decision": {
            "regle": "bit = 1 si r1 > r2 (égalité : 0)",
            "instants_r1": instants_r1,
            "instants_r2": instants_r2,
            "r1": r1,
            "r2": r2,
        },
        "bits": chaine_bits(m.bits),
        "crc": {
            "recu": chaine_bits(m.bits[88:]),
            "calcule": chaine_bits(encoder_crc(m.bits[:88])[88:]),
            "reste": chaine_bits(reste),
            "valide": not reste.any(),
        },
        "segments": segments_trame(m.registre.type),
        "champs": champs_registre(m),
        "variante_bruitee": variante_bruitee(m.bits, Fse),
    }


def variante_bruitee(bits, Fse=4):
    """Ce qu'il faut au navigateur pour bruiter une copie propre de la trame,
    puis la démoduler et vérifier son CRC lui-même (aucun résultat bruité
    précalculé)."""
    propre = np.r_[preambule(Fse), moduler_ppm(bits, Fse)]
    EbN0 = np.arange(0, 14.01, 0.5)
    Pb = teb_theorique(EbN0)
    return {
        "signal_propre": propre.astype(int).tolist(),
        "debut_donnees": 8 * Fse,
        "modele": {
            "description": "bruit blanc gaussien réel ajouté à chaque échantillon (modèle de la tâche 1) : "
                           "r = s + sqrt(N0/2)·n, n ~ N(0, 1) indépendants ; Eb = Fse/2 (énergie d'une impulsion) ; "
                           "N0 = Eb / 10^(EbN0_dB/10)",
            "Eb": Fse / 2,
            "EbN0_dB_min": 0,
            "EbN0_dB_max": 14,
            "EbN0_dB_defaut": 8,
        },
        "theorie": [
            {"EbN0_dB": float(x), "teb": float(p), "p_trame_intacte": float((1 - p) ** 112)}
            for x, p in zip(EbN0, Pb)
        ],
    }


def choisir_exemples(messages, adresse="4CA706"):
    """Une identification, une position et une vitesse du même avion, les
    trames de plus forte corrélation de chaque catégorie."""
    categories = {"identite": range(1, 5), "position": range(9, 19), "vitesse": [19]}
    res = []
    for nom, types in categories.items():
        candidats = [m for m in messages if m.registre.adresse == adresse and m.registre.type in types]
        res.append((nom, max(candidats, key=lambda m: m.correlation)))
    return res


# ---------------------------------------------------------------- avions et messages

def message_compact(m):
    c = {"buffer": m.buffer, "position": m.position + 1, "correlation": round(m.correlation, 4), "hex": hexa(m.bits)}
    c.update(champs_registre(m))
    return c


def avions_export(messages, avions):
    res = []
    for a in sorted(avions, key=lambda a: a.adresse):
        ms = a.messages
        positions = [
            {
                "buffer": m.buffer, "position": m.position + 1, "ftc": m.registre.type,
                "latitude": m.registre.latitude, "longitude": m.registre.longitude,
                "altitude_ft": m.registre.altitude, "cprf": m.registre.cprf,
                "tracee": m.registre.type <= 17,
            }
            for m in ms if m.registre.latitude is not None
        ]
        vitesses = [m.registre for m in ms if m.registre.vitesse_kt is not None]
        types = {}
        for m in ms:
            types[str(m.registre.type)] = types.get(str(m.registre.type), 0) + 1
        res.append({
            "adresse": a.adresse,
            "indicatif": a.indicatif.strip() if a.indicatif else None,
            "nb_messages": len(ms),
            "par_type": types,
            "buffers": sorted({m.buffer for m in ms}),
            "dans_reference": a.adresse not in AVIONS_ABSENTS_DE_LA_REFERENCE,
            "une_seule_trame": len(ms) == 1,
            "note": NOTES_AVIONS.get(a.adresse),
            "positions": positions,
            "vitesse": None if not vitesses else {
                "nb_messages": len(vitesses),
                "vitesse_kt": round(float(np.mean([r.vitesse_kt for r in vitesses])), 1),
                "cap_deg": round(vitesses[-1].cap_deg, 1),
                "taux_vertical_ft_min": vitesses[-1].taux_vertical_ft_min,
            },
        })
    return res


# ---------------------------------------------------------------- courbes

def teb_export(t1, t4, matlab):
    def liste(x, n=None):
        return [None if not np.isfinite(v) else (round(float(v), n) if n else float(v)) for v in np.ravel(x)]

    return {
        "tache1": {
            "description": "PPM, Fse = 20, paquets de 1000 bits, au moins 200 erreurs par point, bruit réel",
            "EbN0_dB": liste(t1["EbN0_dB"]),
            "theorie": liste(t1["Pb_th"]),
            "python": {"teb": liste(t1["ber"]), "erreurs": t1["nb_err"].tolist(), "teb_energie": liste(t1["ber_energie"])},
            "matlab": {"teb": liste(matlab["t1_ber"]), "erreurs": np.ravel(matlab["t1_nb_err"]).astype(int).tolist(),
                       "teb_energie": liste(matlab["t1_ber_energie"])},
        },
        "tache4": {
            "description": "trames de 112 bits, retard sur [0, 100 Te], fréquence sur [-1, 1] kHz, phase quelconque, "
                           "bruit complexe de variance N0/2 par voie ; au moins 3000 trames et 300 erreurs par point, "
                           "30000 trames au plus",
            "EbN0_dB": liste(t4["EbN0_dB"]),
            "theorie_coherente": liste(teb_theorique(t4["EbN0_dB"])),
            "theorie_non_coherente": liste(0.5 * np.exp(-(10 ** (t4["EbN0_dB"] / 10)) / 2)),
            "python": {
                "teb_retard_estime": liste(t4["ber_sync"]), "erreurs_retard_estime": t4["err_sync"].tolist(),
                "teb_vrai_retard": liste(t4["ber_parfait"]), "erreurs_vrai_retard": t4["err_parfait"].tolist(),
                "trames": t4["trames"].tolist(), "part_mal_calees": liste(t4["mal_calees"], 4),
            },
            "matlab": {
                "teb_retard_estime": liste(matlab["t4_ber_sync"]),
                "erreurs_retard_estime": np.ravel(matlab["t4_err_sync"]).astype(int).tolist(),
                "teb_vrai_retard": liste(matlab["t4_ber_parfait"]),
                "erreurs_vrai_retard": np.ravel(matlab["t4_err_parfait"]).astype(int).tolist(),
                "part_mal_calees": liste(matlab["t4_trames_mal_calees"], 4),
            },
            "seuil_1e3": {
                "theorie_coherente_dB": round(t4["x_th"], 3),
                "theorie_non_coherente_dB": round(t4["x_nc"], 3),
                "python": {k: round(float(t4[k]), 3) for k in ("x_sync", "x_parfait", "perte", "perte_decision", "perte_synchro")},
                "matlab": {k: round(float(matlab["t4_" + k].item()), 3)
                           for k in ("x_sync", "x_parfait", "perte", "perte_decision", "perte_synchro")},
            },
        },
    }


def dsp_export(graine=22, Nfft=256, Fe=20e6, Rb=1e6):
    """Tâche 2 : DSP de s_l estimée (Mon_Welch, 2 000 FFT de 256 points) contre analytique."""
    rng = np.random.default_rng(graine)
    Fse = round(Fe / Rb)
    b = rng.integers(0, 2, 100 * Nfft)
    y, f = mon_welch(moduler_ppm(b, Fse), Nfft, Fe)
    continue_, echantillonnee = dsp_analytique(f, Fe, Rb)
    i0 = int(np.flatnonzero(f == 0)[0])
    raie = 0.25 / (Fe / Nfft)
    garde = echantillonnee > 1e-2 * echantillonnee.max()
    garde[i0] = False
    bande = garde & (np.abs(f) <= 5e6)
    def dB(x):
        # null (zéro de la DSP) sous -150 dB
        v = 10 * np.log10(np.maximum(x, 1e-300))
        return [round(float(a), 2) if a > -150 else None for a in v]
    return {
        "description": "s_l PPM (Fse = 20, Fe = 20 MHz), Mon_Welch sans recouvrement ni fenêtre, Nfft = 256",
        "nb_fft": len(b) * Fse // Nfft,
        "f_MHz": [round(float(v) / 1e6, 6) for v in f],
        "estimee_dB": dB(y),
        "analytique_continue_dB": dB(continue_),
        "analytique_echantillonnee_dB": dB(echantillonnee),
        "raie_f0": {"f_MHz": 0.0, "dB": round(10 * np.log10(raie), 2), "description": "1/4·δ(f) étalée sur une case de Fe/Nfft"},
        "puissance": round(float(y.sum() * Fe / Nfft), 4),
        "rapport_raie": round(float(y[i0] / raie), 4),
        "ecart_moyen_echantillonnee_dB": round(float(np.mean(np.abs(10 * np.log10(y[garde] / echantillonnee[garde])))), 3),
        "ecart_moyen_continue_5MHz_dB": round(float(np.mean(np.abs(10 * np.log10(y[bande] / continue_[bande])))), 3),
    }


# ---------------------------------------------------------------- assemblage

def construire(messages, avions, tampons, t1, t4, matlab, Fse=4, Rs=4e6):
    exemples = [trame_pas_a_pas(m, tampons[:, m.buffer - 1], nom, Fse) for nom, m in choisir_exemples(messages)]
    intervalles, residu, segments = estimer_intervalles(messages)
    pd = premier_dernier(messages)
    nb_positions = sum(m.registre.latitude is not None for m in messages)
    par_type = {}
    for m in messages:
        par_type[str(m.registre.type)] = par_type.get(str(m.registre.type), 0) + 1
    return {
        "version": VERSION,
        "source": {
            "enregistrements": "data/buffers.mat du sujet TS229 (TS229 course repository) : 9 buffers de 0,5 s "
                               "reçus par la radio logicielle de l'ENSEIRB-Matmeca",
            "chaine": "portage Python de la chaîne MATLAB des étudiants, égal au MATLAB bloc par bloc",
        },
        "parametres": {
            "Fe_Hz": int(Rs),
            "Rb_bit_s": 1_000_000,
            "Fse": Fse,
            "echantillons_par_buffer": int(tampons.shape[0]),
            "nb_buffers": int(tampons.shape[1]),
            "seuil": bf.SEUIL,
            "reference": {"nom": "ENSEIRB-Matmeca", "latitude": bf.REF_LAT, "longitude": bf.REF_LON},
            "preambule": preambule(Fse).astype(int).tolist(),
            "polynome_crc": chaine_bits(POLYNOME),
            "positions": "position = indice du premier échantillon du préambule dans le buffer, à partir de 1 (comme MATLAB)",
        },
        "trames_exemples": exemples,
        "messages": [message_compact(m) for m in messages],
        "avions": avions_export(messages, avions),
        "chiffres": {
            "messages": len(messages),
            "contenus_distincts": len({m.bits.tobytes() for m in messages}),
            "avions": len(avions),
            "positions": nb_positions,
            "positions_tracees": sum(len(a.trajectoire) for a in avions),
            "par_type": par_type,
        },
        "comparaison_reference": {
            "source": "src/Tests/task8.m (chaîne de l'enseignant, fonctions .p) ; README.md",
            "reference": REFERENCE_ENSEIGNANT,
            "retrouves": "93/93 (76 trames distinctes, chacune une fois)",
            "avions_en_plus": sorted(AVIONS_ABSENTS_DE_LA_REFERENCE),
            "explication": "la référence compte 17 doublons (deux échantillons voisins au-dessus du seuil) et ne "
                           "décode ni la vitesse (FTC 19), ni FTC 18, ni les messages d'état (FTC 28, 29, 31)",
        },
        "seuil": {
            "valeur": bf.SEUIL,
            "origine": "valeur fournie avec le sujet (adsb_app), vérifiée après coup",
            "reperes": {
                "preambule_aligne": 1.0,
                "demi_echantillon": round(float(np.sqrt(3) / 2), 4),
                "fenetre_dans_les_donnees_max": round(float(1 / np.sqrt(2)), 4),
                "un_bit_trop_tot": 0.5,
            },
        },
        "duree": {
            "est_une_estimation": True,
            "base": "aucune date dans buffers.mat ; pour chaque avion et chaque paire de buffers consécutifs où il a "
                    "une position, distance parcourue / vitesse sol annoncée (FTC 19) = somme des intervalles entre "
                    "ces buffers ; moindres carrés",
            "segments": len(segments),
            "avions": len({s["adresse"] for s in segments}),
            "intervalles_s": [round(float(x), 1) for x in intervalles],
            "total_s": round(float(intervalles.sum()), 1),
            "residu_rms_s": round(residu, 1),
            "avions_vus_aux_buffers_1_et_9": [
                {"adresse": e["adresse"], "distance_km": round(e["distance_m"] / 1e3, 1),
                 "vitesse_kt": round(e["vitesse_kt"], 1), "duree_s": round(e["duree_s"], 1)} for e in pd
            ],
            "fourchette": "environ 1 min 38 à 1 min 54 entre le premier et le dernier buffer (98 à 113,5 s pour les "
                          "avions vus aux buffers 1 et 9, 106 s par moindres carrés)",
            "signal_enregistre_s": tampons.shape[0] * tampons.shape[1] / Rs,
        },
        "teb": teb_export(t1, t4, matlab),
        "dsp": dsp_export(),
    }
