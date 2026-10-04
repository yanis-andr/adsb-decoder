function res = test_task1_ber()
% Tâche 1 ST6 : TEB de la chaîne PPM (Fse = 20, paquets de Nb = 1000 bits)
% pour Eb/N0 de 0 à 10 dB, au moins 100 erreurs par point, contre
% Pb = 0,5 erfc(sqrt(Eb/2N0)) (ST7).
% Bruit réel de variance N0/2 par échantillon ; Eb = somme de p1^2.
% Courbes : demodulatePPM (r1 > r2, maximum de vraisemblance) et, pour
% comparaison, l'ancienne règle par énergie |r1|^2 > |r2|^2.

rng(11);
Fse = 20;
EbN0_dB = 0:1:10;
numPoints = length(EbN0_dB);
minErrors = 200;     % le sujet en demande au moins 100
Nb = 1000;

ber_ml = zeros(1, numPoints);
ber_energy = zeros(1, numPoints);
nb_err_ml = zeros(1, numPoints);

Eb = sum(modulatePPM(1, Fse).^2);   % = Fse/2 = 10
EbN0_linear = 10.^(EbN0_dB/10);
Pb_th = 0.5 * erfc(sqrt(EbN0_linear / 2));

for idx = 1:numPoints
    N0 = Eb / EbN0_linear(idx);
    noiseVar = N0/2;

    numBits = 0;
    numErrs = 0;
    numErrsE = 0;
    while (numErrs < minErrors)
        b = randi([0,1], 1, Nb);
        s = modulatePPM(b, Fse);
        r = s + sqrt(noiseVar) * randn(size(s));

        numErrs = numErrs + sum(b ~= demodulatePPM(r, Fse));

        % ancienne règle (énergie), même signal reçu
        R = reshape(r, Fse, []);
        r1 = sum(R(1:Fse/2, :));
        r2 = sum(R(Fse/2+1:end, :));
        numErrsE = numErrsE + sum(b ~= (abs(r1).^2 > abs(r2).^2));

        numBits = numBits + Nb;
    end
    ber_ml(idx) = numErrs / numBits;
    ber_energy(idx) = numErrsE / numBits;
    nb_err_ml(idx) = numErrs;
    fprintf('    Eb/N0 = %2d dB : TEB = %.3e (théorie %.3e), règle énergie %.3e\n', ...
            EbN0_dB(idx), ber_ml(idx), Pb_th(idx), ber_energy(idx));
end

% la simulation doit se superposer à la théorie (200 erreurs : ~7 % d'écart type)
ecart = max(abs(ber_ml ./ Pb_th - 1));
assert(all(nb_err_ml >= 100), 'moins de 100 erreurs sur un point');
assert(ecart < 0.25, 'TEB simulé trop loin de la théorie (écart relatif %.2f)', ecart);

fig = figure('Name', 'Tâche 1 - TEB');
semilogy(EbN0_dB, Pb_th, 'r-', 'LineWidth', 2); hold on;
semilogy(EbN0_dB, ber_ml, 'bo', 'LineWidth', 1.5, 'MarkerSize', 8);
semilogy(EbN0_dB, ber_energy, 'k^--', 'LineWidth', 1, 'MarkerSize', 6);
grid on;
ylim([1e-4 1]);
xlabel('E_b/N_0 (dB)');
ylabel('TEB');
legend('P_b = 0,5 erfc(\surd(E_b/2N_0))', 'simulé, demodulatePPM (r_1 > r_2)', ...
    'simulé, ancienne règle |r_1|^2 > |r_2|^2', 'Location', 'southwest');
title(sprintf('PPM binaire, Fse = %d, N_b = %d, au moins %d erreurs par point', Fse, Nb, minErrors));
sauver_figure(fig, 'tache1_teb');

res.ber10 = ber_ml(end);
% courbes, pour comparer le portage Python (exporter_python)
res.EbN0_dB = EbN0_dB;
res.ber = ber_ml;
res.nb_err = nb_err_ml;
res.ber_energie = ber_energy;
res.Pb_th = Pb_th;
res.chiffres = sprintf('TEB à 10 dB = %.2e (théorie %.2e), écart relatif max %.0f %% sur 0-10 dB ; ancienne règle %.2e à 10 dB', ...
    ber_ml(end), Pb_th(end), 100*ecart, ber_energy(end));
fprintf('  Tâche 1 ST6 : %s\n', res.chiffres);
end
