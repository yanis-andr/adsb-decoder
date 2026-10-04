# ADS-B receiver in Python

Port of the MATLAB chain in `../src`, one module per MATLAB block, with the same names and comments (in French), checked block by block against the MATLAB outputs. See the [main README](../README.md) for the context, the results and how to fetch the subject files.

```bash
uv sync
uv run pytest                    # no data needed: blocks against MATLAB vectors, bit error rates
uv run python -m adsb.etude      # needs ../data/buffers.mat: decodes the 9 recordings, writes export/adsb-portfolio.json
```

## Modules

| Module | MATLAB | Role |
|---|---|---|
| `ppm` | `modulatePPM`, `get_preamble`, `preambule`, `demodulatePPM` | PPM modulation, preamble, decision r1 > r2 (real signal) or \|r1\| > \|r2\| (complex) |
| `crc` | `encodeCRC`, `decodeCRC` | bitwise polynomial division, 24 × 88 parity matrix to decode in batches |
| `synchro` | `shift_estimation`, steps 2 and 3 of `process_buffer` | normalised correlation with the preamble, local maxima above the threshold |
| `cpr` | `cprMod`, `cprNL`, `cpr2LatLon` | local CPR decoding around ENSEIRB-MATMECA |
| `registres` | `bit2registre` | 112 bits to a register, plus `decoder_vitesse` (velocity, type 19), which the MATLAB chain does not have |
| `buffers` | `process_buffer`, `update_liste_avion` | the 9 recordings: DF 17 messages with a good CRC, list of aircraft |
| `dsp` | `Mon_Welch`, analytic PSD of `test_task2_dsp` | task 2 |
| `teb` | `test_task1_ber`, `test_task4_ber_sync` | simulated bit error rates, loss at 10⁻³ |
| `trajectoires` | | time covered by the recordings, estimated from the announced velocities |
| `portfolio`, `etude` | | JSON export for the portfolio page and printed summary |

Two conventions differ from MATLAB. Positions in a buffer are counted from 0 in the code (`Message.position`), from 1 in MATLAB and in the export. An empty MATLAB register field is `None`, `planeName` is called `indicatif` and `crcErrFlag` is called `erreur_crc`.

## Checked against MATLAB

`src/Tests/exporter_python.m` writes the reference vectors into `tests/donnees/`. The repository only ships `blocs_synthetiques.mat`: the vectors computed on random inputs (PPM, CRC, CPR, synchronisation, Welch PSD). The other files are computed from the subject's recordings and are regenerated with MATLAB (see the main README). When they are present, the tests use them.

| Block | Cases | Result |
|---|---|---|
| `moduler_ppm`, `preambule` | 20 sequences of symbols −1, 0, 1, Fse = 4 and 20, task 4 preamble | identical |
| `demoduler_ppm` | 66 real signals (noiseless, noisy from 0 to 10 dB, ties r1 = r2) and 60 complex ones | same bits |
| `encoder_crc`, `decoder_crc`, `reste_crc` | 300 messages with 0 to 3 flipped bits, parity matrix | same bits, same decisions, same remainders |
| `cpr_nl`, `cpr_mod`, `cpr_vers_lat_lon` | 5,012 latitudes, 204 pairs, 400 positions with two references | identical (exact equality) |
| `bits_vers_registre` | the 27 frames of `adsb_msgs.mat`, corrupted, noisy, synthetic callsign, leading zero address, DF 18, type 19 | same fields (needs the MATLAB export) |
| `estimer_retard` | 25 task 4 frames, noiseless and noisy | same delay, correlation equal to within 2.5·10⁻¹⁶ |
| `mon_welch` | real PPM signal, complex noise | relative gap 10⁻¹⁷ |
| buffers, candidates | the 9 recordings: 1,729 local maxima above 0.75 | same positions, same bits, same CRC (needs the MATLAB export) |
| buffers, messages | the 9 recordings | same 171 messages, at the same positions, with the same bits and fields (needs the MATLAB export) |

The equality does not depend on a lucky rounding. On the 9 recordings, every correlation is at least 1.3·10⁻⁵ away from the threshold, every maximum exceeds its neighbours by at least 4·10⁻⁴ and \|r1 − r2\| is at least 1.2·10⁻⁵, while the rounding gaps between MATLAB and NumPy are around 10⁻¹⁶.

## Bit error rates, computed again

Same settings and stopping rules as the MATLAB scripts, other random draws (NumPy generator). The relative uncertainty of a rate counted on n errors is about 1/√n, so 7 % for 200 errors.

| | Python | MATLAB | Theory |
|---|---|---|---|
| Task 1, bit error rate at 10 dB | 7.87·10⁻⁴ | 7.72·10⁻⁴ | 7.83·10⁻⁴ |
| Task 4, 10⁻³ reached at | 11.10 dB | 11.11 dB | 9.80 dB (task 1) |
| Task 4, loss | 1.30 dB | 1.31 dB | |
| of which non-coherent decision | 1.15 dB | 1.18 dB | 1.14 dB |
| of which synchronisation | 0.15 dB | 0.13 dB | |

Task 2 (PSD, 2,000 FFTs of 256 points): power 0.5000, line at f = 0 within 0.1 % of its expected height, mean gap of 0.19 dB to the sampled analytic PSD (MATLAB 0.21 dB).

## Export

`python -m adsb.etude` writes `export/adsb-portfolio.json` (about 140 KiB, French keys), read by the interactive page of the portfolio. Top-level keys: `version`, `source`, `parametres`, `trames_exemples` (three real frames step by step, with raw I/Q samples), `messages` (the 171 messages), `avions` (the 26 aircraft), `chiffres`, `comparaison_reference`, `seuil`, `duree`, `teb`, `dsp`. It contains extracts of the recordings, so it is not versioned. `tests/test_export.py` checks its shape once it has been produced.
