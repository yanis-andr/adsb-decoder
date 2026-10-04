function res = test_task1_st5()
% Tâche 1, ST5 : allures de s_l(t), r_l(t) et r_m pour [1 0 0 1 0],
% sans bruit, signaux causaux.
% r_l = s_l * p1(-t) rendu causal (retard de Ts) ; r_m est r_l
% échantillonné toutes les Ts/2 au bout de chaque demi-symbole.
% r_l est multiplié par Te pour être en µs : le pic vaut
% v0 = intégrale de |p1|^2 = Ts/2 = 0,5 µs.

Fe  = 20e6;
Te  = 1/Fe;
Ts  = 1e-6;
Fse = 20;

b = [1 0 0 1 0];

sl = modulatePPM(b, Fse);
sl = sl(:).';
t_us = (0:length(sl)-1)*Te*1e6;

% filtre adapté p1(-t), retardé de Ts pour être causal
p1  = [ones(1,Fse/2), zeros(1,Fse/2)];
hMF = fliplr(p1);
rl  = conv(sl, hMF) * Te * 1e6;     % en µs
t_rl_us = (0:length(rl)-1)*Te*1e6;

% échantillons r_m : fin du 1er demi-symbole (r_2k) et du 2e (r_2k+1)
K  = numel(b);
r2k_indices = Fse + (0:K-1)*Fse;
r2kplus1_indices = r2k_indices + Fse/2;
r2k = rl(r2k_indices);
r2kplus1 = rl(r2kplus1_indices);
t_r2k_us = (r2k_indices-1)*Te*1e6;
t_r2kplus1_us = (r2kplus1_indices-1)*Te*1e6;

% décision : impulsion dans la 1re moitié -> bit 1
b_hat = double(r2k > r2kplus1);
v0 = Ts/2*1e6;
assert(isequal(b_hat, b), 'ST5 : décision fausse sans bruit');
assert(all(abs(max(r2k, r2kplus1) - v0) < 1e-9) && all(abs(min(r2k, r2kplus1)) < 1e-9), ...
    'ST5 : r_m doit valoir v0 ou 0');
assert(isequal(demodulatePPM(sl, Fse), b), 'ST5 : demodulatePPM en désaccord');

fig = figure('Name','Allures sl(t), rl(t) et rm');
plot(t_us, sl, 'b-', 'LineWidth', 1.5); hold on;
plot(t_rl_us, rl, 'r--', 'LineWidth', 1.2);
stem(t_r2k_us, r2k, 'go', 'LineWidth', 1.5, 'MarkerSize', 8);
stem(t_r2kplus1_us, r2kplus1, 'mo', 'LineWidth', 1.5, 'MarkerSize', 8);
grid on;
xlabel('t [\mus]'); ylabel('Amplitude');
ylim([-0.1 1.2]);
title(sprintf('s_l(t), r_l(t) et r_m (sans bruit), b = [%s], décision [%s]', ...
    num2str(b), num2str(b_hat)));
legend('s_l(t)', 'r_l(t) = s_l * p_1(-t) (\mus)', 'r_{2k}', 'r_{2k+1}', ...
    'Location', 'southoutside', 'Orientation', 'horizontal');
sauver_figure(fig, 'tache1_st5_allures');

res.chiffres = sprintf('b = [%s] -> r_2k = [%s], r_2k+1 = [%s] (µs), décision [%s]', ...
    num2str(b), num2str(r2k, '%.2g '), num2str(r2kplus1, '%.2g '), num2str(b_hat));
fprintf('  Tâche 1 ST5 : %s\n', res.chiffres);
end
