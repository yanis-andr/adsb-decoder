function res = test_task4_ber_sync()
% Tâche 4 ST7 : TEB avec désynchronisation aléatoire de chaque trame
% (delta_t sur [0, 100 Te], delta_f sur [-1, 1] kHz, phi0 sur [0, 2 pi]),
% et perte en dB à TEB = 1e-3 par rapport à Pb = 0,5 erfc(sqrt(Eb/2N0)).
%
% Bruit complexe de variance N0/2 sur chaque voie (I et Q) : la voie en
% phase voit le même bruit qu'en tâche 1, Eb/N0 garde le même sens.
% Récepteur : préambule -> shift_estimation (retard <= 100 Te) ->
% demodulatePPM, qui compare |r1| et |r2| (phase inconnue, ST4).
% Pour séparer les pertes, chaque trame est aussi démodulée avec le vrai
% retard ; la courbe théorique de cette décision non cohérente est
% 0,5 exp(-Eb/2N0).
% Le sujet demande 0 à 10 dB par pas de 1 dB ; on va jusqu'à 14 dB pour
% que la courbe simulée atteigne 1e-3, avec des demi-dB autour.

rng(47);
Fe = 20e6;
Te = 1/Fe;
Rb = 1e6;
Fse = Fe/Rb;
retard_max = 100;
Nbits = 112;          % bits par trame (88 + 24 de CRC)
minErrors = 300;      % le sujet en demande 100 ; les erreurs arrivent par
minFrames = 3000;     % paquets (trame mal calée : ~56 erreurs), d'où plus
maxFrames = 30000;    % de trames et d'erreurs par point

% pas de 1 dB, plus des demi-dB autour de TEB = 1e-3 pour l'interpolation
EbN0_dB = [0:1:9, 9.5:0.5:12, 13, 14];
numPoints = length(EbN0_dB);
sp = preambule(Fse);
Eb = sum(modulatePPM(1, Fse).^2);   % = 10

ber_sync = zeros(1, numPoints);     % retard estimé
ber_parfait = zeros(1, numPoints);  % vrai retard
err_sync = zeros(1, numPoints);
err_parfait = zeros(1, numPoints);
trames_mal_calees = zeros(1, numPoints);

for idx = 1:numPoints
    N0 = Eb / 10^(EbN0_dB(idx)/10);
    numBits = 0; numErrs = 0; numErrsP = 0; numFrames = 0; malCalees = 0;
    while (numErrs < minErrors || numFrames < minFrames) && numFrames < maxFrames
        b = randi([0,1], 1, Nbits);
        sl = [sp, modulatePPM(b, Fse)];

        delta_t = randi([0, retard_max]);
        delta_f = (rand - 0.5) * 2e3;
        phi0 = rand * 2*pi;
        sl_tx = [zeros(1, delta_t), sl, zeros(1, retard_max - delta_t)];
        t = (0:length(sl_tx)-1) * Te;
        yl = sl_tx .* exp(-1j*2*pi*delta_f*t + 1j*phi0);
        yl = yl + sqrt(N0/2) * (randn(size(yl)) + 1j*randn(size(yl)));

        delta_t_hat = shift_estimation(yl, sp, retard_max);
        malCalees = malCalees + (delta_t_hat ~= delta_t);

        idx_data = length(sp) + (1:Nbits*Fse);
        b_hat = demodulatePPM(yl(delta_t_hat + idx_data), Fse);
        b_hat_p = demodulatePPM(yl(delta_t + idx_data), Fse);

        numErrs = numErrs + sum(b ~= b_hat);
        numErrsP = numErrsP + sum(b ~= b_hat_p);
        numBits = numBits + Nbits;
        numFrames = numFrames + 1;
    end
    ber_sync(idx) = numErrs / numBits;
    ber_parfait(idx) = numErrsP / numBits;
    err_sync(idx) = numErrs;
    err_parfait(idx) = numErrsP;
    trames_mal_calees(idx) = malCalees / numFrames;
    fprintf('    Eb/N0 = %4.1f dB : TEB = %.2e (%d err.), vrai retard %.2e (%d err.), %d trames, %.1f %% mal calées\n', ...
            EbN0_dB(idx), ber_sync(idx), numErrs, ber_parfait(idx), numErrsP, numFrames, 100*trames_mal_calees(idx));
end

% Courbes théoriques
EbN0_lin = 10.^(EbN0_dB/10);
Pb_th = 0.5 * erfc(sqrt(EbN0_lin/2));
Pb_nc = 0.5 * exp(-EbN0_lin/2);

% Eb/N0 à TEB = 1e-3
cible = 1e-3;
x_th = 10*log10(2 * erfcinv(2*cible)^2);
x_nc = 10*log10(2 * log(0.5/cible));
x_sync = croisement(EbN0_dB, ber_sync, err_sync, cible);
x_parfait = croisement(EbN0_dB, ber_parfait, err_parfait, cible);
perte_totale = x_sync - x_th;       % ce que demande le sujet
perte_decision = x_parfait - x_th;  % décision |r1| > |r2| (théorie : x_nc - x_th)
perte_synchro = x_sync - x_parfait; % retard estimé au lieu du vrai

% vérifications : la courbe au vrai retard suit la théorie non cohérente
ok = err_parfait >= 100;
ecart_nc = max(abs(ber_parfait(ok) ./ Pb_nc(ok) - 1));
assert(ecart_nc < 0.3, 'TEB au vrai retard loin de 0,5 exp(-Eb/2N0) (écart %.2f)', ecart_nc);
assert(~isnan(x_sync) && perte_totale > 0, 'TEB = 1e-3 non atteint');
% la perte due à la décision non cohérente suit la théorie (1,14 dB)
assert(abs(perte_decision - (x_nc - x_th)) < 0.3, 'perte de décision %.2f dB au lieu de %.2f dB', ...
    perte_decision, x_nc - x_th);

% Figure
fig = figure('Name', 'Tâche 4 - TEB avec désynchronisation');
axes(fig); hold on; set(gca, 'YScale', 'log'); box on;
trace_points(EbN0_dB, ber_parfait, err_parfait, 100, 'ks');
trace_points(EbN0_dB, ber_sync, err_sync, 100, 'bo');
x_fin = linspace(EbN0_dB(1), EbN0_dB(end), 200);
semilogy(x_fin, 0.5*erfc(sqrt(10.^(x_fin/10)/2)), 'r-', 'LineWidth', 2);
semilogy(x_fin, 0.5*exp(-10.^(x_fin/10)/2), 'm--', 'LineWidth', 2);
yline(cible, 'k:', 'LineWidth', 1);
plot([x_th x_sync], [cible cible], 'b-', 'LineWidth', 3);
grid on;
xlabel('E_b/N_0 (dB)');
ylabel('TEB');
ylim([1e-5, 1]);
xlim([EbN0_dB(1) EbN0_dB(end)]);
title({sprintf('TEB = 10^{-3} atteint à %.2f dB au lieu de %.2f dB : perte %.2f dB', x_sync, x_th, perte_totale), ...
    sprintf('= %.2f dB de décision non cohérente + %.2f dB de synchronisation', perte_decision, perte_synchro)});
legend('simulé, vrai retard', 'simulé, retard estimé', ...
    'P_b = 0,5 erfc(\surd(E_b/2N_0)) (tâche 1)', 'P_b = 0,5 exp(-E_b/2N_0) (décision |r_1| > |r_2|)', ...
    'TEB = 10^{-3}', 'perte', 'Location', 'southwest');
sauver_figure(fig, 'tache4_teb_synchro');

res.perte = perte_totale;
% courbes, pour comparer le portage Python (exporter_python)
res.EbN0_dB = EbN0_dB;
res.ber_sync = ber_sync;
res.ber_parfait = ber_parfait;
res.err_sync = err_sync;
res.err_parfait = err_parfait;
res.trames_mal_calees = trames_mal_calees;
res.x_sync = x_sync;
res.x_parfait = x_parfait;
res.x_th = x_th;
res.x_nc = x_nc;
res.perte_decision = perte_decision;
res.perte_synchro = perte_synchro;
res.chiffres = sprintf(['TEB = 1e-3 à %.2f dB (théorie %.2f dB) : perte %.2f dB = %.2f dB de décision ' ...
    'non cohérente (théorie %.2f dB) + %.2f dB de synchronisation ; TEB à 10 dB = %.2e'], ...
    x_sync, x_th, perte_totale, perte_decision, x_nc - x_th, perte_synchro, ber_sync(EbN0_dB == 10));
fprintf('  Tâche 4 ST7 : %s\n', res.chiffres);
end

function x = croisement(EbN0_dB, ber, nb_err, cible)
    % Eb/N0 où le TEB passe sous la cible (interpolation en log du TEB)
    x = NaN;
    for i = 1:length(ber)-1
        if ber(i) >= cible && ber(i+1) < cible && nb_err(i) >= 100 && nb_err(i+1) >= 100
            a = log10(ber(i)); c = log10(ber(i+1));
            x = EbN0_dB(i) + (EbN0_dB(i+1) - EbN0_dB(i)) * (log10(cible) - a) / (c - a);
            return;
        end
    end
end

function trace_points(x, ber, nb_err, minErrors, style)
    % points légitimes (>= 100 erreurs) pleins, les autres vides
    ok = nb_err >= minErrors;
    semilogy(x(ok), ber(ok), [style '-'], 'LineWidth', 1.5, 'MarkerSize', 7, ...
        'MarkerFaceColor', style(1));
    h = semilogy(x(~ok & ber > 0), ber(~ok & ber > 0), style, 'MarkerSize', 7);
    set(h, 'HandleVisibility', 'off');
end
