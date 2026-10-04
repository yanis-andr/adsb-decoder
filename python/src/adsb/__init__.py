"""Récepteur ADS-B : portage Python de la chaîne MATLAB du projet TS229.

Un module par bloc : ppm (modulation, démodulation), crc, synchro
(corrélation avec le préambule), cpr, registres (couche MAC), buffers
(enregistrements réels), dsp (densité spectrale), teb (taux d'erreur
binaire simulés). etude rejoue tout et écrit l'export du portfolio.
"""
