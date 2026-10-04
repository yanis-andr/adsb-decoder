function res = test_task4_sync()
% Tâche 4, ST5-ST6 : synchronisation temporelle par corrélation avec le
% préambule. delta_t uniforme sur [0, 100 Te], delta_f sur [-1, 1] kHz,
% phi0 sur [0, 2 pi], alpha = 1.
% ST6 : sans bruit, delta_t doit être retrouvé exactement (500 tirages).
% Avec bruit (Eb/N0 = 10 dB, bruit complexe de variance N0/2 par voie) :
% répartition des erreurs d'estimation.

rng(41);
Fe = 20e6;
Te = 1/Fe;
Rb = 1e6;
Fse = Fe/Rb;
retard_max = 100;            % delta_t <= 100 Te (sujet)
sp = preambule(Fse);
Eb = Fse/2;

N = 500;
err_sans_bruit = zeros(1, N);
err_bruit = zeros(1, N);
N0 = Eb / 10^(10/10);
for k = 1:N
    [yl_clean, delta_t] = trame_desynchronisee(sp, Fse, Te, retard_max);
    err_sans_bruit(k) = shift_estimation(yl_clean, sp, retard_max) - delta_t;
    nl = sqrt(N0/2) * (randn(size(yl_clean)) + 1j*randn(size(yl_clean)));
    err_bruit(k) = shift_estimation(yl_clean + nl, sp, retard_max) - delta_t;
end
assert(all(err_sans_bruit == 0), 'ST6 : %d erreurs de synchronisation sans bruit', sum(err_sans_bruit ~= 0));
part_exacte = mean(err_bruit == 0);
part_1 = mean(abs(err_bruit) <= 1);
part_grosse = mean(abs(err_bruit) > 2);

% un tirage illustré, avec bruit
[yl_clean, delta_t, sl] = trame_desynchronisee(sp, Fse, Te, retard_max);
yl = yl_clean + sqrt(N0/2) * (randn(size(yl_clean)) + 1j*randn(size(yl_clean)));
[delta_t_hat, rho] = shift_estimation(yl, sp, retard_max);

fig = figure('Name', 'Tâche 4 - Synchronisation', 'Position', [100 100 800 700]);
subplot(3,1,1);
t_sp = (0:length(sp)-1) * Te * 1e6;
plot(t_sp, sp, 'b-', 'LineWidth', 1.5);
grid on; xlabel('t (\mus)'); ylabel('s_p(t)');
title('Préambule s_p(t)'); xlim([0 8]); ylim([-0.1 1.2]);

subplot(3,1,2);
t_y = (0:length(yl)-1) * Te * 1e6;
plot(t_y, abs(yl), 'Color', [0.6 0.6 0.6]); hold on;
plot(t_y, abs(yl_clean), 'b-', 'LineWidth', 1.2);
xline(delta_t*Te*1e6, 'g--', 'LineWidth', 1.5);
grid on; xlabel('t (\mus)'); ylabel('|y_l(t)|'); xlim([0 30]);
title(sprintf('Signal reçu, \\delta_t = %d T_e, E_b/N_0 = 10 dB', delta_t));
legend('avec bruit', 'sans bruit', 'début réel', 'Location', 'northeast');

subplot(3,1,3);
plot(0:length(rho)-1, abs(rho), 'r-', 'LineWidth', 1.5); hold on;
plot(delta_t_hat, abs(rho(delta_t_hat+1)), 'go', 'MarkerSize', 10, 'LineWidth', 2);
plot(delta_t, abs(rho(delta_t+1)), 'bx', 'MarkerSize', 10, 'LineWidth', 2);
grid on; xlabel('\delta''_t (échantillons)'); ylabel('|\rho(\delta''_t)|');
title(sprintf('Corrélation normalisée : estimé %d, vrai %d', delta_t_hat, delta_t));
legend('|\rho|', 'estimé', 'vrai', 'Location', 'northeast');
sauver_figure(fig, 'tache4_synchro');

res.chiffres = sprintf(['sans bruit : 0 erreur sur %d tirages ; à 10 dB : %.1f %% exacts, ' ...
    '%.1f %% à +-1 échantillon, %.1f %% d''erreurs > 2 échantillons'], ...
    N, 100*part_exacte, 100*part_1, 100*part_grosse);
fprintf('  Tâche 4 ST5-ST6 : %s\n', res.chiffres);
end

function [yl, delta_t, sl] = trame_desynchronisee(sp, Fse, Te, retard_max)
    % préambule + 112 bits, retard, décalage de fréquence et phase
    b = randi([0,1], 1, 112);
    sl = [sp, modulatePPM(b, Fse)];
    delta_t = randi([0, retard_max]);
    delta_f = (rand - 0.5) * 2e3;
    phi0 = rand * 2*pi;
    sl_retard = [zeros(1, delta_t), sl, zeros(1, retard_max - delta_t + 20)];
    t = (0:length(sl_retard)-1) * Te;
    yl = sl_retard .* exp(-1j*2*pi*delta_f*t + 1j*phi0);
end
