"""Densité spectrale de puissance (tâche 2) : portage de Mon_Welch.m et DSP
analytique de test_task2_dsp.m."""

import numpy as np


def mon_welch(x, Nfft, Fe):
    """Welch sans recouvrement ni fenêtre : moyenne des |FFT|^2 sur des blocs
    de Nfft points. Rend (y en W/Hz, f de -Fe/2 à Fe/2 - Fe/Nfft) ; somme(y)·Fe/Nfft
    est la puissance de x."""
    x = np.asarray(x).ravel()
    P = len(x) // Nfft
    blocs = x[: P * Nfft].reshape(P, Nfft)            # un bloc par ligne
    X = np.fft.fftshift(np.fft.fft(blocs, axis=1), axes=1)
    y = np.mean(np.abs(X) ** 2 / (Fe * Nfft), axis=0)
    f = np.arange(-Nfft // 2, Nfft // 2) * (Fe / Nfft)
    return y, f


def dsp_analytique(f, Fe, Rb=1e6):
    """DSP de s_l (PPM, impulsions de Ts/2) sans la raie 1/4·δ(f) :
    continue : Ts/4 · sinc²(f·Ts/2) · sin²(π·f·Ts/2) ;
    échantillonnée (impulsions de Fse/2 échantillons, repliée à Fe) :
    Te²/Ts · D(f)² · sin²(π·f·Ts/2), avec D(f) = sin(π·f·Ts/2) / sin(π·f·Te)."""
    Ts = 1 / Rb
    Te = 1 / Fe
    Fse = round(Fe / Rb)
    continue_ = Ts / 4 * np.sinc(f * Ts / 2) ** 2 * np.sin(np.pi * f * Ts / 2) ** 2
    D = np.full(np.shape(f), Fse / 2)
    nz = np.abs(np.sin(np.pi * f * Te)) > 1e-12
    D[nz] = np.sin(np.pi * f[nz] * Ts / 2) / np.sin(np.pi * f[nz] * Te)
    echantillonnee = Te**2 / Ts * D**2 * np.sin(np.pi * f * Ts / 2) ** 2
    return continue_, echantillonnee
