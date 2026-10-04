function res = task8_seuil()
% Tâche 8 : ce que coûte et ce que rapporte le seuil de détection.
% Pour des seuils de 0,5 à 0,9, sur les 9 buffers : nombre de candidats
% (maxima locaux de la corrélation), trames DF 17 à CRC bon, trames à CRC bon
% d'un autre format, avions. Le seuil n'est pas choisi ici (voir
% README.md) : ce script vérifie après coup ce qu'il fait.
% Hors de main_tests (environ une minute). Figure : tache8_seuil.png.
% La démodulation et le CRC sont ceux de demodulatePPM et encodeCRC, écrits
% en version vectorielle pour traiter 2,5 millions de candidats :
%  - bit = 1 si la première moitié du symbole porte plus d'énergie (r1 > r2) ;
%  - le CRC est linéaire : le mot w est valide si P·w(1:88) + w(89:112) = 0
%    modulo 2, où la colonne i de P est la parité de encodeCRC pour le
%    i-ème vecteur unité.

Fse = 4;
seuils = 0.50:0.05:0.90;
S = load(fullfile(dossier_projet(), 'data', 'buffers.mat'), 'buffers');
p = get_preamble(Fse);
Lp = numel(p);
Ltrame = 112 * Fse;

% matrice de parité (24 x 88) construite avec encodeCRC
P = zeros(24, 88);
for i = 1:88
    e = zeros(1, 88);
    e(i) = 1;
    c = encodeCRC(e);
    P(:, i) = c(89:112).';
end
% vérification : les mots de encodeCRC ont un syndrome nul
tests = randi([0 1], 20, 88);
for t = 1:20
    c = encodeCRC(tests(t, :));
    assert(all(mod(P * c(1:88).' + c(89:112).', 2) == 0), 'matrice de parité fausse');
end

% distance minimale du code sur 112 bits : une erreur de poids w passe le
% CRC si son syndrome est nul, c'est-à-dire si le OU exclusif des syndromes
% de ses w bits faux est nul. Syndromes des 112 erreurs simples en entiers.
s = uint32(2.^(23:-1:0) * [P, eye(24)]);
paires = nchoosek(1:112, 2);
s2 = bitxor(s(paires(:, 1)), s(paires(:, 2)));
triplets = nchoosek(1:112, 3);
s3 = bitxor(bitxor(s(triplets(:, 1)), s(triplets(:, 2))), s(triplets(:, 3)));
assert(all(s ~= 0), 'erreur de poids 1 non détectée');
assert(numel(unique(s)) == 112, 'erreur de poids 2 non détectée');
assert(~any(ismember(s2, s)), 'erreur de poids 3 non détectée');
assert(numel(unique(s2)) == numel(s2), 'erreur de poids 4 non détectée');
assert(~any(ismember(s3, s2)), 'erreur de poids 5 non détectée');
[~, ~, groupe] = unique(s3);
taille = accumarray(groupe, 1);
poids6 = sum(taille .* (taille - 1) / 2) / 10;   % chaque mot de poids 6 : 10 paires de triplets
fprintf('  CRC sur 112 bits : toute erreur de 1 à 5 bits est détectée ; %d motifs de 6 bits passent\n', poids6);

C = struct('buf', {}, 'pos', {}, 'rho', {}, 'bits', {});   % candidats à CRC bon
nb_cand = zeros(size(seuils));
coupes = 0;
for b = 1:size(S.buffers, 2)
    y = abs(S.buffers(:, b).');
    N = numel(y);
    num = conv(y, fliplr(p), 'valid');
    energie = movsum(y.^2, [0 Lp-1]);
    energie = energie(1:numel(num));
    rho = zeros(size(num));
    rho(energie > 0) = num(energie > 0) ./ sqrt(sum(p.^2) * energie(energie > 0));
    g = [-Inf, rho(1:end-1)];
    d = [rho(2:end), -Inf];
    maxloc = find(rho >= seuils(1) & rho >= g & rho >= d);
    kmax = N - Lp - Ltrame + 1;
    coupes = coupes + sum(maxloc > kmax & rho(maxloc) >= 0.75);
    maxloc = maxloc(maxloc <= kmax);
    for s = 1:numel(seuils)
        nb_cand(s) = nb_cand(s) + sum(rho(maxloc) >= seuils(s));
    end
    % démodulation et CRC par paquets
    for debut = 1:50000:numel(maxloc)
        k = maxloc(debut:min(debut+49999, end));
        idx = k + Lp + (0:Ltrame-1).';            % 448 x n
        x = reshape(y(idx), Fse, 112, []);        % échantillons x bits x candidats
        bits = squeeze(sum(x(1:Fse/2, :, :), 1) > sum(x(Fse/2+1:end, :, :), 1));   % 112 x n
        if isvector(bits)
            bits = bits(:);
        end
        syndrome = mod(P * double(bits(1:88, :)) + double(bits(89:112, :)), 2);
        bons = find(~any(syndrome, 1));
        for j = bons
            C(end+1) = struct('buf', b, 'pos', k(j), 'rho', rho(k(j)), 'bits', double(bits(:, j).')); %#ok<AGROW>
        end
    end
end

% doublons : même trame lue à deux positions voisines (on garde la première)
garde = true(1, numel(C));
for i = 2:numel(C)
    if C(i).buf == C(i-1).buf && C(i).pos < C(i-1).pos + Lp + Ltrame && isequal(C(i).bits, C(i-1).bits)
        garde(i) = false;
    end
end
C = C(garde);
df = arrayfun(@(c) bin2dec(char(c.bits(1:5) + '0')), C);
adr = arrayfun(@(c) bin2dec(char(c.bits(9:32) + '0')), C);
r = [C.rho];

% les trames à CRC bon d'un autre format sont-elles des trames DF 17 lues un
% bit trop tôt ? Lu un bit trop tôt, le mot vaut [0, t(1:111)] pour une
% trame t ; c'est un mot de code si [t(1:111), 0] en est un. On remet donc
% le mot en place, avec un 0 à la fin, et on regarde s'il donne une trame
% DF 17 valide, puis si cette trame a été lue à sa vraie place.
autres = find(df ~= 17);
decalees = 0;
vraie_trame_lue = 0;
for i = autres
    t = [C(i).bits(2:112), 0];
    if C(i).bits(1) == 0 && all(mod(P * t(1:88).' + t(89:112).', 2) == 0) && bin2dec(char(t(1:5) + '0')) == 17
        decalees = decalees + 1;
        j = find([C.buf] == C(i).buf & abs([C.pos] - (C(i).pos + Fse)) <= 2 & df == 17);
        if ~isempty(j) && isequal(C(j(1)).bits, t)
            vraie_trame_lue = vraie_trame_lue + 1;
        else
            fprintf('  trame lue un bit trop tôt, sans trame valide à sa place : buffer %d, position %d, corrélation %.3f, %s\n', ...
                C(i).buf, C(i).pos, C(i).rho, bits2hex(C(i).bits));
        end
    else
        fprintf('  trame à CRC bon hors DF 17, non décalée : buffer %d, position %d, corrélation %.3f, %s\n', ...
            C(i).buf, C(i).pos, C(i).rho, bits2hex(C(i).bits));
    end
end

fprintf('  seuil | candidats | fausses alarmes CRC attendues | DF 17 à CRC bon | avions | autres DF à CRC bon\n');
lignes = cell(numel(seuils), 1);
for s = 1:numel(seuils)
    sel = r >= seuils(s);
    lignes{s} = sprintf('  %.2f | %d | %.1e | %d | %d | %d', seuils(s), nb_cand(s), nb_cand(s) * 2^-24, ...
        sum(sel & df == 17), numel(unique(adr(sel & df == 17))), sum(sel & df ~= 17));
    fprintf('%s\n', lignes{s});
end
fprintf('  %d trames à CRC bon hors DF 17, dont %d trames DF 17 lues un bit trop tôt (%d avec la vraie trame lue aussi), corrélation max %.3f\n', ...
    numel(autres), decalees, vraie_trame_lue, max([r(autres), 0]));
fprintf('  DF 17 sous 0,75 : %d trames, corrélations %s\n', sum(df == 17 & r < 0.75), mat2str(sort(r(df == 17 & r < 0.75)), 3));
fprintf('  trames coupées par la fin d''un buffer (maximum >= 0,75 trop près de la fin) : %d\n', coupes);

% figure
fig = figure('Position', [100 100 900 380]);
subplot(1, 2, 1);
bords = 0.5:0.02:1;
histogram(r(df == 17), bords, 'FaceColor', [0 0.447 0.741]);
hold on;
histogram(r(df ~= 17), bords, 'FaceColor', [0.85 0.325 0.098]);
% un bit trop tôt : 0,5 ; fenêtre dans les données : au plus 1/sqrt(2) ;
% seuil ; préambule à un demi-échantillon : sqrt(3)/2
reperes = [0.5, 1/sqrt(2), 0.75, sqrt(3)/2];
noms = {'1 bit tôt', 'données', 'seuil', '1/2 éch.'};
for k = 1:numel(reperes)
    xline(reperes(k), '--k', noms{k}, 'LabelVerticalAlignment', 'top', 'FontSize', 8);
end
ylim([0, 1.4 * max(histcounts(r(df == 17), bords))]);   % étiquettes au-dessus des barres
xlabel('corrélation du préambule');
ylabel('trames à CRC bon');
legend('DF 17', 'autres DF', 'Location', 'west');
title('Trames à CRC bon');
subplot(1, 2, 2);
semilogy(seuils, nb_cand, 'o-');
hold on;
xline(0.75, '--k');
xlabel('seuil');
ylabel('candidats (9 buffers)');
grid on;
title('Candidats décodés');
sauver_figure(fig, 'tache8_seuil');

res.poids6 = poids6;
res.chiffres = sprintf('%d DF 17 à CRC bon au-dessus de 0,5 dont %d sous 0,75 ; %d autres DF, dont %d décalées d''un bit, corrélation au plus %.3f ; %d trames coupées', ...
    sum(df == 17), sum(df == 17 & r < 0.75), numel(autres), decalees, max([r(autres), 0]), coupes);
res.lignes = lignes;
fprintf('  Seuil : %s\n', res.chiffres);
end

function h = bits2hex(bits)
    h = dec2hex(bin2dec(reshape(char(bits + '0'), 4, []).')).';
end
