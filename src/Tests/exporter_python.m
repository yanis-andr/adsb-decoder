function exporter_python(avec_teb)
% Exporte les vecteurs de référence du portage Python, calculés par la
% chaîne MATLAB terminée (aucune fonction .p), dans python/tests/donnees/ :
%  - blocs.mat : entrées et sorties de chaque bloc (PPM, CRC, CPR,
%    bit2registre, shift_estimation, Mon_Welch) sur des cas fixes et bruités,
%    dont les 27 trames de adsb_msgs.mat ;
%  - buffers_reference.mat : sur les 9 buffers de buffers.mat, tous les
%    candidats (maxima locaux de la corrélation au-dessus du seuil) avec leur
%    corrélation, leurs bits et leur CRC, puis les 171 messages rendus par
%    process_buffer (buffer, position, corrélation, bits, champs) ;
%  - teb_matlab.mat : les courbes de TEB des tâches 1 et 4 (avec_teb, par
%    défaut vrai ; environ 70 s).
% Les buffers eux-mêmes restent dans data/ (hors git).
% Depuis la racine du dépôt :
%   matlab -batch "addpath('src/PHY','src/MAC','src/General','src/Tests'); exporter_python"

if nargin < 1
    avec_teb = true;
end
racine = dossier_projet();
sortie = fullfile(racine, 'python', 'tests', 'donnees');
if ~exist(sortie, 'dir')
    mkdir(sortie);
end
refLon = -0.606629;  % ENSEIRB-Matmeca (antenne)
refLat = 44.806884;

%% 1) blocs
rng(2026);
B = struct();

% --- modulatePPM, get_preamble : symboles 1, 0 et -1 (pas d'impulsion)
B.ppm_symboles = randi([-1 1], 20, 30);
for Fse = [4 20]
    m = zeros(20, 30*Fse);
    for k = 1:20
        m(k, :) = modulatePPM(B.ppm_symboles(k, :), Fse);
    end
    B.(sprintf('ppm_module_%d', Fse)) = m;
    B.(sprintf('preambule_%d', Fse)) = get_preamble(Fse);
end
B.preambule_tache4_20 = preambule(20);   % préambule de la tâche 4

% --- demodulatePPM : signal réel sans bruit et bruité, complexe bruité,
% et égalités r1 = r2 (décision 0)
for Fse = [4 20]
    n = 40 - 20 * (Fse == 20);   % 40 cas à Fse = 4, 20 à Fse = 20 (taille du fichier)
    bits = randi([0 1], n, 112);
    reel = zeros(n, 112*Fse);
    cplx = complex(zeros(n, 112*Fse));
    for k = 1:n
        s = modulatePPM(bits(k, :), Fse);
        N0 = (Fse/2) / 10^((k-1)*10/n/10);       % Eb/N0 de 0 à 10 dB
        if k <= 4
            reel(k, :) = s;                       % sans bruit
        else
            reel(k, :) = s + sqrt(N0/2) * randn(size(s));
        end
        cplx(k, :) = s * exp(1j*2*pi*rand) + sqrt(N0/2) * (randn(size(s)) + 1j*randn(size(s)));
    end
    % égalités : demi-symboles de même somme
    egal = [zeros(1, 112*Fse); ones(1, 112*Fse); repmat([ones(1, Fse/2), 2*ones(1, Fse/2)], 1, 112)];
    egal(3, 1:Fse) = [2*ones(1, Fse/2), ones(1, Fse/2)];
    reel = [reel; egal]; %#ok<AGROW>
    dr = zeros(size(reel, 1), 112);
    for k = 1:size(reel, 1)
        dr(k, :) = demodulatePPM(reel(k, :), Fse);
    end
    dc = zeros(n, 112);
    for k = 1:n
        dc(k, :) = demodulatePPM(cplx(k, :), Fse);
    end
    B.(sprintf('demod_bits_%d', Fse)) = bits;
    B.(sprintf('demod_reel_%d', Fse)) = reel;
    B.(sprintf('demod_reel_sortie_%d', Fse)) = dr;
    B.(sprintf('demod_cplx_%d', Fse)) = cplx;
    B.(sprintf('demod_cplx_sortie_%d', Fse)) = dc;
end

% --- encodeCRC, decodeCRC : 300 messages, 0 à 3 bits inversés
N = 300;
B.crc_messages = randi([0 1], N, 88);
B.crc_codes = zeros(N, 112);
B.crc_recus = zeros(N, 112);
B.crc_decodes = zeros(N, 88);
B.crc_erreur = zeros(N, 1);
B.crc_reste = zeros(N, 24);
for k = 1:N
    c = encodeCRC(B.crc_messages(k, :));
    r = c;
    pos = randperm(112, mod(k, 4));
    r(pos) = 1 - r(pos);
    [d, e] = decodeCRC(r);
    B.crc_codes(k, :) = c;
    B.crc_recus(k, :) = r;
    B.crc_decodes(k, :) = d;
    B.crc_erreur(k) = e;
    % reste de la division (decodeCRC ne le rend pas) : le CRC est linéaire,
    % le reste de r vaut la parité de r(1:88) plus r(89:112)
    p = encodeCRC(r(1:88));
    B.crc_reste(k, :) = xor(p(89:112), r(89:112));
end
% matrice de parité 24 x 88 (colonne i : parité du i-ème vecteur unité)
B.crc_parite = zeros(24, 88);
for i = 1:88
    e = zeros(1, 88);
    e(i) = 1;
    c = encodeCRC(e);
    B.crc_parite(:, i) = c(89:112).';
end

% --- cprNL, cprMod, cpr2LatLon
lat = [-90 + 180*rand(1, 5000), 0, 1e-5, 10, 45, 86.9, 87, -87, 87.1, -87.1, 89.9, 90, -90];
B.cpr_nl_lat = lat;
B.cpr_nl = cprNL(lat);
B.cpr_mod_a = [-400 + 800*rand(1, 200), -6, 6, 0, 360];
B.cpr_mod_b = [1 + 50*rand(1, 200), 6, 6, 6, 6];
B.cpr_mod = arrayfun(@cprMod, B.cpr_mod_a, B.cpr_mod_b);
n = 400;
B.cpr_LAT = randi([0 2^17-1], n, 1);
B.cpr_LON = randi([0 2^17-1], n, 1);
B.cpr_cprf = randi([0 1], n, 1);
B.cpr_refLat = [refLat * ones(200, 1); -85 + 170*rand(200, 1)];
B.cpr_refLon = [refLon * ones(200, 1); -180 + 360*rand(200, 1)];
B.cpr_lat = zeros(n, 1);
B.cpr_lon = zeros(n, 1);
for k = 1:n
    [B.cpr_lon(k), B.cpr_lat(k)] = cpr2LatLon(B.cpr_LAT(k), B.cpr_LON(k), B.cpr_cprf(k), B.cpr_refLat(k), B.cpr_refLon(k));
end

% --- bit2registre : les 27 trames, corrompues, bruitées, indicatif
% synthétique (codes 0, 32, 63), adresse à zéro de tête, autres DF
S = load(fullfile(racine, 'data', 'adsb_msgs.mat'), 'adsb_msgs');
M = double(S.adsb_msgs);
B.adsb_msgs = M.';                          % 27 x 112
trames = M.';
for k = 1:27
    t = M(:, k).';
    pos = randperm(112, randi(3));
    t(pos) = 1 - t(pos);
    trames(end+1, :) = t; %#ok<AGROW>
end
Fse = 4;
N0 = (Fse/2) / 10^(4/10);
for k = 1:27
    s = modulatePPM(M(:, k).', Fse);
    trames(end+1, :) = demodulatePPM(s + sqrt(N0/2) * randn(size(s)), Fse); %#ok<AGROW>
end
t = M(:, 12).';
t = t(1:88);
t(33+8:33+13) = [0 0 0 0 0 0];
t(33+14:33+19) = [1 0 0 0 0 0];
t(33+20:33+25) = [1 1 1 1 1 1];
trames(end+1, :) = encodeCRC(t);
t = M(:, 12).';
t = t(1:88);
t(9:32) = dec2bin(hex2dec('0200AE'), 24) - '0';
trames(end+1, :) = encodeCRC(t);
t = M(:, 1).';
t = t(1:88);
t(1:5) = [1 0 0 1 0];                       % DF 18
trames(end+1, :) = encodeCRC(t);
t = M(:, 1).';
t = t(1:88);
t(33:37) = [1 0 0 1 1];                     % FTC 19 (non décodé)
trames(end+1, :) = encodeCRC(t);
regs = cell(1, size(trames, 1));
for k = 1:size(trames, 1)
    regs{k} = bit2registre(trames(k, :), refLon, refLat);
end
B.reg_trames = trames;
B = ajouter_registres(B, 'reg', regs);
B.reg_refLon = refLon;
B.reg_refLat = refLat;

% --- shift_estimation : trames de la tâche 4 (Fse = 20), avec et sans bruit
Fe = 20e6; Te = 1/Fe; Fse = 20; retard_max = 100;
sp = preambule(Fse);
n = 25;
L = length(sp) + 112*Fse + retard_max;
B.synchro_yl = complex(zeros(n, L));
B.synchro_retard = zeros(n, 1);
B.synchro_estime = zeros(n, 1);
B.synchro_rho = complex(zeros(n, retard_max + 1));
for k = 1:n
    b = randi([0 1], 1, 112);
    sl = [sp, modulatePPM(b, Fse)];
    delta_t = randi([0, retard_max]);
    delta_f = (rand - 0.5) * 2e3;
    phi0 = rand * 2*pi;
    sl_tx = [zeros(1, delta_t), sl, zeros(1, retard_max - delta_t)];
    t = (0:length(sl_tx)-1) * Te;
    yl = sl_tx .* exp(-1j*2*pi*delta_f*t + 1j*phi0);
    if k > 5
        N0 = (Fse/2) / 10^((k-6)/2/10);       % Eb/N0 de 0 à 9,5 dB
        yl = yl + sqrt(N0/2) * (randn(size(yl)) + 1j*randn(size(yl)));
    end
    [B.synchro_estime(k), rho] = shift_estimation(yl, sp, retard_max);
    B.synchro_yl(k, :) = yl;
    B.synchro_retard(k) = delta_t;
    B.synchro_rho(k, :) = rho;
end
B.synchro_sp = sp;
B.synchro_retard_max = retard_max;

% --- Mon_Welch : PPM réel (Fse = 20) et bruit complexe
b = randi([0 1], 1, 1536);
B.welch_x1 = modulatePPM(b, 20);
[B.welch_y1, B.welch_f1] = Mon_Welch(B.welch_x1, 256, 20e6);
B.welch_x2 = randn(1, 256*40 + 17) + 1j*randn(1, 256*40 + 17);
[B.welch_y2, B.welch_f2] = Mon_Welch(B.welch_x2, 256, 4e6);

save(fullfile(sortie, 'blocs.mat'), '-struct', 'B', '-v7');
fprintf('blocs.mat : %d variables\n', numel(fieldnames(B)));

%% 2) les 9 buffers
seuil = 0.75;
S = load(fullfile(racine, 'data', 'buffers.mat'), 'buffers', 'Rs');
Fse = S.Rs / 1e6;
p = get_preamble(Fse);
Lp = numel(p);
Ltrame = 112 * Fse;
C = struct('buf', {}, 'pos', {}, 'rho', {}, 'bits', {}, 'erreur', {});
messages = struct('buf', {}, 'pos', {}, 'corr', {}, 'bits', {}, 'registre', {});
nb_au_dessus = zeros(1, size(S.buffers, 2));
for b = 1:size(S.buffers, 2)
    % candidats, calculés comme dans process_buffer
    y = abs(S.buffers(:, b).');
    Nb = numel(y);
    num = conv(y, fliplr(p), 'valid');
    energie = movsum(y.^2, [0 Lp-1]);
    energie = energie(1:Nb-Lp+1);
    rho = zeros(1, Nb-Lp+1);
    ok = energie > 0;
    rho(ok) = num(ok) ./ sqrt(sum(p.^2) * energie(ok));
    nb_au_dessus(b) = sum(rho >= seuil);
    g = [-Inf, rho(1:end-1)];
    d = [rho(2:end), -Inf];
    cand = find(rho >= seuil & rho >= g & rho >= d);
    cand = cand(cand <= Nb - Lp - Ltrame + 1);
    for k = cand
        bits = demodulatePPM(y(k+Lp : k+Lp+Ltrame-1), Fse);
        [~, e] = decodeCRC(bits);
        C(end+1) = struct('buf', b, 'pos', k, 'rho', rho(k), 'bits', bits, 'erreur', e); %#ok<AGROW>
    end
    % messages rendus par process_buffer
    [regs, corr, pos] = process_buffer(S.buffers(:, b), refLon, refLat, seuil, Fse);
    for k = 1:numel(regs)
        bits = demodulatePPM(y(pos(k) + Lp + (0:Ltrame-1)), Fse);
        assert(isequaln(bit2registre(bits, refLon, refLat), regs{k}), 'bits relus incohérents');
        assert(corr(k) == rho(pos(k)), 'corrélation différente');
        messages(end+1) = struct('buf', b, 'pos', pos(k), 'corr', corr(k), 'bits', bits, 'registre', regs{k}); %#ok<AGROW>
    end
end
assert(numel(messages) == 171, '%d messages au lieu de 171', numel(messages));
R = struct();
R.seuil = seuil;
R.Fse = Fse;
R.refLon = refLon;
R.refLat = refLat;
R.nb_au_dessus_seuil = nb_au_dessus;
R.cand_buf = [C.buf].';
R.cand_pos = [C.pos].';
R.cand_rho = [C.rho].';
R.cand_bits = uint8(vertcat(C.bits));
R.cand_erreur = [C.erreur].';
R.msg_buf = [messages.buf].';
R.msg_pos = [messages.pos].';
R.msg_corr = [messages.corr].';
R.msg_bits = uint8(vertcat(messages.bits));
R = ajouter_registres(R, 'msg', {messages.registre});
save(fullfile(sortie, 'buffers_reference.mat'), '-struct', 'R', '-v7');
fprintf('buffers_reference.mat : %d candidats, %d messages\n', numel(C), numel(messages));

%% 3) courbes de TEB (tâches 1 et 4)
if avec_teb
    set(groot, 'DefaultFigureVisible', 'off');
    T = struct();
    r1 = test_task1_ber();
    close all;
    T.t1_EbN0_dB = r1.EbN0_dB;
    T.t1_ber = r1.ber;
    T.t1_nb_err = r1.nb_err;
    T.t1_ber_energie = r1.ber_energie;
    T.t1_Pb_th = r1.Pb_th;
    r4 = test_task4_ber_sync();
    close all;
    for c = {'EbN0_dB', 'ber_sync', 'ber_parfait', 'err_sync', 'err_parfait', 'trames_mal_calees', ...
             'x_sync', 'x_parfait', 'x_th', 'x_nc', 'perte', 'perte_decision', 'perte_synchro'}
        T.(['t4_' c{1}]) = r4.(c{1});
    end
    save(fullfile(sortie, 'teb_matlab.mat'), '-struct', 'T', '-v7');
    fprintf('teb_matlab.mat : tâche 1 (%d points), tâche 4 (%d points)\n', numel(T.t1_ber), numel(T.t4_ber_sync));
end
end

function S = ajouter_registres(S, prefixe, regs)
% Registres en tableaux : un champ vide devient NaN (nombres) ou une ligne
% vide (indicatif : drapeau a_indicatif à 0).
    n = numel(regs);
    nombre = @(x) ternaire(isempty(x), NaN, double(x));
    champs = {'format', 'type', 'altitude', 'cprf', 'latitude', 'longitude', 'crcErrFlag'};
    for c = champs
        S.([prefixe '_' c{1}]) = cellfun(@(r) nombre(r.(c{1})), regs(:));
    end
    S.([prefixe '_adresse']) = char(cellfun(@(r) r.adresse, regs(:), 'UniformOutput', false));
    noms = repmat(' ', n, 8);
    a_nom = zeros(n, 1);
    for k = 1:n
        if ~isempty(regs{k}.planeName)
            noms(k, :) = regs{k}.planeName;
            a_nom(k) = 1;
        end
    end
    S.([prefixe '_planeName']) = noms;
    S.([prefixe '_a_indicatif']) = a_nom;
end

function v = ternaire(c, a, b)
    if c
        v = a;
    else
        v = b;
    end
end
