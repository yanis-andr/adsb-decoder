function res = test_task2_dsp()
% Tâche 2, ST6 : DSP de s_l(t) estimée par Mon_Welch (sans recouvrement,
% sans fenêtre, Nfft = 256) contre la DSP analytique (ST5) :
%   Gamma(f) = Ts/4 * sinc^2(f Ts/2) * sin^2(pi f Ts/2) + 1/4 * delta(f)
% (partie continue de la forme biphase, raie due à la moyenne 0,5).
% Comme s_l est échantillonné (Fse = 20), on trace aussi la même DSP pour
% des impulsions de 10 échantillons, repliée à Fe : c'est elle que
% l'estimateur doit retrouver sur toute la bande.

rng(22);
Nfft = 256;
Fe = 20e6; % Frequence d'echantillonnage
Te = 1/Fe;
Rb = 1e6;% Debit binaire (=debit symbole)
Ts = 1/Rb;
Fse = floor(Fe/Rb); % Nombre d'echantillons par symboles

%% Chaine TX

b = randi([0,1], 1, 100*Nfft);
sl = modulatePPM(b,Fse);

[DSP, f] = Mon_Welch(sl, Nfft, Fe);
DSP = DSP(:).';
nb_fft = floor(length(sl)/Nfft);

%% DSP analytique
mon_sinc = @(x) (x == 0) + (x ~= 0) .* sin(pi*x) ./ (pi*x + (x == 0));
Gamma_c = Ts/4 * mon_sinc(f*Ts/2).^2 .* sin(pi*f*Ts/2).^2;
% version échantillonnée : sinc remplacé par le noyau de Dirichlet
Dir = (Fse/2) * ones(size(f));
nz = abs(sin(pi*f*Te)) > 1e-12;
Dir(nz) = sin(pi*f(nz)*Ts/2) ./ sin(pi*f(nz)*Te);
Gamma_d = Te^2/Ts * Dir.^2 .* sin(pi*f*Ts/2).^2;
% raie en f = 0 : puissance 1/4 répartie sur une case de largeur Fe/Nfft
i0 = find(f == 0);
raie = 0.25 / (Fe/Nfft);

%% Écarts
puissance = sum(DSP) * Fe/Nfft;
rapport_raie = DSP(i0) / raie;
garde = Gamma_d > 1e-2 * max(Gamma_d);                 % hors des zéros
garde(i0) = false;
ecart_d = mean(abs(10*log10(DSP(garde) ./ Gamma_d(garde))));
bande = garde & abs(f) <= 5e6;
ecart_c = mean(abs(10*log10(DSP(bande) ./ Gamma_c(bande))));
haut = garde & abs(f) > 8e6;
ecart_c_haut = mean(10*log10(DSP(haut) ./ Gamma_c(haut)));

assert(nb_fft >= 100, 'au moins 100 FFT demandées');
assert(abs(puissance - 0.5) < 0.01, 'puissance estimée %.3f au lieu de 0,5', puissance);
assert(abs(rapport_raie - 1) < 0.05, 'raie en 0 : rapport %.3f', rapport_raie);
assert(ecart_d < 0.5, 'écart moyen à la DSP échantillonnée : %.2f dB', ecart_d);
% la formule continue ignore le repliement à Fe : 0,48 dB mesuré, d'où
% une tolérance plus large que pour la DSP échantillonnée
assert(ecart_c < 0.7, 'écart moyen à la DSP analytique (|f| <= 5 MHz) : %.2f dB', ecart_c);

%% Affichage
fig = figure('Name', 'Tâche 2 - DSP');
plancher = -110;
dB = @(x) max(10*log10(x), plancher);
plot(f/1e6, dB(DSP), 'b', 'LineWidth', 1.5); hold on;
plot(f/1e6, dB(Gamma_c), 'r--', 'LineWidth', 1.3);
plot(f/1e6, dB(Gamma_d), 'k:', 'LineWidth', 1.3);
plot(0, dB(raie), 'r^', 'MarkerSize', 9, 'MarkerFaceColor', 'r');
xlabel('Fréquence [MHz]');
ylabel('DSP [dB(1/Hz)]');
ylim([plancher, -50]);
title(sprintf('DSP de s_l : Mon\\_Welch (%d FFT de %d points) et DSP analytique', nb_fft, Nfft));
legend('estimée (Mon\_Welch)', 'analytique (impulsions continues)', ...
    'analytique (impulsions échantillonnées, repliée à F_e)', 'raie 1/4 \delta(f) (sur une case)', ...
    'Location', 'southoutside', 'NumColumns', 2);
grid on;
sauver_figure(fig, 'tache2_dsp');

res.chiffres = sprintf(['%d FFT ; puissance %.4f (0,5 attendu) ; raie en 0 : rapport %.3f ; ' ...
    'écart moyen %.2f dB à la DSP échantillonnée, %.2f dB à l''analytique pour |f| <= 5 MHz ' ...
    '(%+.1f dB au-delà de 8 MHz, repliement)'], nb_fft, puissance, rapport_raie, ecart_d, ecart_c, ecart_c_haut);
fprintf('  Tâche 2 ST6 : %s\n', res.chiffres);
end
