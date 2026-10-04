function res = verif_demodulatePPM()
% demodulatePPM contre demodulatePPM_ sur signal réel (sans bruit et
% bruité, Fse = 4 et 20) : décisions identiques.
% Signal complexe : demodulatePPM_ compare les parties réelles (phase
% supposée corrigée) ; la nôtre compare les modules, donc ne dépend pas
% de la phase. On vérifie cette invariance, et l'égalité avec la
% référence quand la phase est nulle et sans bruit.

rng(34);
nb_bits = 0;
nb_diff = 0;
for Fse = [4 20]
    for k = 1:60
        b = randi([0 1], 1, 112);
        s = modulatePPM(b, Fse);
        if mod(k, 2) == 0
            r = s;                                       % sans bruit
        else
            N0 = (Fse/2) / 10^(rand*8/10);               % Eb/N0 de 0 à 8 dB
            r = s + sqrt(N0/2) * randn(size(s));         % bruit réel
        end
        bh = demodulatePPM(r, Fse);
        bh_col = demodulatePPM(r(:), Fse);
        bh_ref = avec_reference(@() demodulatePPM_(r, Fse));
        assert(isrow(bh) && isequal(bh, bh_col), 'demodulatePPM : forme de sortie');
        if mod(k, 2) == 0
            assert(isequal(bh, b), 'erreur de démodulation sans bruit');
        end
        nb_diff = nb_diff + sum(bh ~= bh_ref);
        nb_bits = nb_bits + numel(b);

        % complexe : invariance en phase
        N0 = (Fse/2) / 10^(rand*8/10);
        rc = s + sqrt(N0/2) * (randn(size(s)) + 1j*randn(size(s)));
        assert(isequal(demodulatePPM(rc, Fse), demodulatePPM(rc * exp(1j*2*pi*rand), Fse)), ...
            'décision complexe sensible à la phase');
    end
    sc = complex(modulatePPM(b, Fse));
    assert(isequal(demodulatePPM(sc, Fse), avec_reference(@() demodulatePPM_(sc, Fse)), b), ...
        'signal complexe de phase nulle mal démodulé');
end
assert(nb_diff == 0, '%d décisions différentes de demodulatePPM_', nb_diff);

res.chiffres = sprintf('%d bits réels (sans bruit et bruités) : 0 décision différente de demodulatePPM_ ; décision complexe invariante en phase', nb_bits);
fprintf('  demodulatePPM : %s\n', res.chiffres);
end
