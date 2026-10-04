function res = verif_Mon_Welch()
% Mon_Welch contre Mon_Welch_ : signal PPM, bruit réel, bruit complexe,
% signal PPM bruité. Même grille de fréquences, mêmes valeurs, et somme
% de la DSP x Fe/Nfft égale à la puissance moyenne du signal.

rng(35);
Fe = 20e6;
Fse = 20;
Nfft = 256;
s = modulatePPM(randi([0 1], 1, 3000), Fse);
signaux = {
    'PPM',            s
    'bruit réel',     randn(1, 60000)
    'bruit complexe', randn(60000, 1) + 1j*randn(60000, 1)
    'PPM bruité',     s + 0.7*(randn(size(s)) + 1j*randn(size(s)))
};

ecart_max = 0;
rapports = zeros(1, size(signaux, 1));
for k = 1:size(signaux, 1)
    x = signaux{k, 2};
    [y, f] = Mon_Welch(x, Nfft, Fe);
    [y_ref, f_ref] = avec_reference(@() Mon_Welch_(x, Nfft, Fe));
    assert(isequal(size(y), size(y_ref)) && isequal(size(f), size(f_ref)), ...
        'Mon_Welch : formes de sortie (%s)', signaux{k, 1});
    assert(max(abs(f - f_ref)) < 1e-6, 'Mon_Welch : fréquences (%s)', signaux{k, 1});
    ecart = max(abs(y - y_ref)) / max(y_ref);
    ecart_max = max(ecart_max, ecart);
    rapports(k) = sum(y) / sum(y_ref);

    % somme = puissance moyenne (sur les échantillons utilisés)
    n = floor(numel(x)/Nfft) * Nfft;
    puissance = mean(abs(x(1:n)).^2);
    assert(abs(sum(y)*Fe/Nfft / puissance - 1) < 1e-9, 'Mon_Welch : puissance (%s)', signaux{k, 1});
end
assert(ecart_max < 1e-9, 'Mon_Welch différent de Mon_Welch_ (écart relatif %.2e)', ecart_max);

res.chiffres = sprintf('4 signaux : rapport des puissances à Mon_Welch_ = %.6f à %.6f, écart relatif max %.1e', ...
    min(rapports), max(rapports), ecart_max);
fprintf('  Mon_Welch : %s\n', res.chiffres);
end
