function res = verif_bit2registre()
% bit2registre contre bit2registre_ :
%  - les 27 trames de adsb_msgs.mat (entrée ligne et colonne) ;
%  - les mêmes trames corrompues (1 à 3 bits inversés) : crcErrFlag = 1 ;
%  - les mêmes trames passées par modulation, bruit et démodulation ;
%  - un indicatif synthétique avec les codes 0, 32 et 63 ;
%  - une adresse à zéro de tête (0x0200AE).
% Écarts voulus (non comparés) : la référence écrit l'adresse sans zéro
% de tête (testé à part) ; elle décode aussi DF = 18,
% les positions au sol (FTC 5 à 8) et rend [] pour FTC 18 ; nous suivons
% le sujet (DF = 17, FTC 1 à 4 et 9 à 18), et le sujet dit d'ignorer
% le bit Q de l'altitude.

refLon = -0.606629;  % ENSEIRB-Matmeca
refLat = 44.806884;
S = load(fullfile(dossier_projet(), 'data', 'adsb_msgs.mat'), 'adsb_msgs');
M = S.adsb_msgs;
champs = {'format','adresse','type','planeName','altitude','cprf','latitude','longitude','crcErrFlag'};

rng(36);
nb_comp = 0;
nb_crc_faux = 0;

% 1) trames telles quelles, ligne et colonne
for k = 1:size(M, 2)
    t = M(:, k).';
    r_ref = avec_reference(@() bit2registre_(t, refLon, refLat));
    comparer(bit2registre(t, refLon, refLat), r_ref, champs, k);
    comparer(bit2registre(t(:), refLon, refLat), r_ref, champs, k);
    nb_comp = nb_comp + 1;
end

% 2) trames corrompues et 3) trames bruitées (Eb/N0 = 4 dB, Fse = 4)
Fse = 4;
N0 = (Fse/2) / 10^(4/10);
for k = 1:size(M, 2)
    for essai = 1:2
        t = M(:, k).';
        if essai == 1
            pos = randperm(112, randi(3));
            t(pos) = 1 - t(pos);
        else
            s = modulatePPM(t, Fse);
            t = demodulatePPM(s + sqrt(N0/2) * randn(size(s)), Fse);
        end
        r_ref = avec_reference(@() bit2registre_(t, refLon, refLat));
        r = bit2registre(t, refLon, refLat);
        % on ne compare que les trames que les deux décodent (DF 17, mêmes FTC)
        if isempty(r_ref) || r.format ~= 17 || isempty(r.type) || r.type == 18
            continue;
        end
        % bit Q (8e bit de l'altitude) à 0 : le sujet dit de l'ignorer,
        % la référence change alors de codage ; altitude non comparée
        if r.type >= 9 && t(33+8+7) == 0
            comparer(r, r_ref, setdiff(champs, {'altitude'}), k);
        else
            comparer(r, r_ref, champs, k);
        end
        nb_comp = nb_comp + 1;
        nb_crc_faux = nb_crc_faux + r.crcErrFlag;
    end
end
assert(nb_crc_faux > 0, 'aucune trame à CRC faux comparée');

% 4) indicatif synthétique : codes 0, 32 et 63
t = M(:, 12).';                 % trame d'identification (FTC 4)
assert(bin2dec(char(t(33:37) + '0')) == 4, 'trame 12 : identification attendue');
t = t(1:88);
t(33+8:33+13) = [0 0 0 0 0 0];  % caractère 1 : code 0
t(33+14:33+19) = [1 0 0 0 0 0]; % caractère 2 : code 32
t(33+20:33+25) = [1 1 1 1 1 1]; % caractère 3 : code 63
t = encodeCRC(t);
r_ref = avec_reference(@() bit2registre_(t, refLon, refLat));
r = bit2registre(t, refLon, refLat);
comparer(r, r_ref, champs, 0);
nb_comp = nb_comp + 1;

% 5) adresse à zéro de tête (0x0200AE, un avion des buffers) : nous
% écrivons 6 chiffres hexadécimaux (24 bits), la référence supprime le zéro
% de tête ('200AE') ; écart voulu, même valeur numérique
t = M(:, 12).';
t = t(1:88);
t(9:32) = dec2bin(hex2dec('0200AE'), 24) - '0';
t = encodeCRC(t);
r_ref = avec_reference(@() bit2registre_(t, refLon, refLat));
r = bit2registre(t, refLon, refLat);
comparer(r, r_ref, setdiff(champs, {'adresse'}), 0);
assert(strcmp(r.adresse, '0200AE') && strcmp(r_ref.adresse, '200AE'), ...
    'adresse : %s pour nous, %s pour la référence', r.adresse, r_ref.adresse);
nb_comp = nb_comp + 1;

% contenu attendu sur adsb_msgs.mat
r1 = bit2registre(M(:, 12), refLon, refLat);
assert(strcmp(r1.adresse, '3420CA') && strcmp(strtrim(r1.planeName), 'IBE3405'), 'avion IBE3405 attendu');

res.chiffres = sprintf('%d registres identiques à bit2registre_ (27 trames, corrompues, bruitées, dont %d à CRC faux ; adresse 0200AE sur 6 chiffres, 200AE pour la référence)', ...
    nb_comp, nb_crc_faux);
fprintf('  bit2registre : %s\n', res.chiffres);
end

function comparer(r, r_ref, champs, k)
    assert(isstruct(r_ref), 'trame %d : la référence ne rend pas de registre', k);
    assert(isequal(fieldnames(r), fieldnames(r_ref)), 'trame %d : champs différents', k);
    for c = champs
        a = r.(c{1});
        b = r_ref.(c{1});
        if isnumeric(a) && ~isempty(a) && any(strcmp(c{1}, {'latitude', 'longitude'}))
            ok = isequal(size(a), size(b)) && max(abs(a - b)) < 1e-9;
        else
            ok = isequal(a, b) || (isempty(a) && isempty(b));
        end
        assert(ok, 'trame %d : champ %s différent', k, c{1});
    end
end
