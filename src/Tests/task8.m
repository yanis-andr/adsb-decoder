function res = task8()
% Tâche 8 : décoder les 9 enregistrements réels de buffers.mat avec notre
% chaîne (process_buffer, update_liste_avion, aucune fonction .p), tracer la
% carte, puis comparer message par message à la chaîne de l'enseignant.
% Un message est commun s'il a le même buffer, la même position (à un
% échantillon près) et les mêmes 112 bits (donc la même adresse).
% Figures : docs/figures/tache8_carte.png (carte du sujet) et
% tache8_carte_large.png (tous les avions placés).

refLon = -0.606629;  % ENSEIRB-Matmeca (antenne)
refLat = 44.806884;
seuil = 0.75;        % justification : README.md
S = load(fullfile(dossier_projet(), 'data', 'buffers.mat'), 'buffers', 'Rs');
Rs = S.Rs;
Fse = Rs / 1e6;
nb_buffers = size(S.buffers, 2);

%% 1) notre chaîne, sous les pièges des fonctions .p
% le piège lui-même doit marcher
try
    sans_fonctions_p(@() process_buffer_(S.buffers(:, 1), refLon, refLat, seuil, Fse));
    error('task8:piege', 'le piège des fonctions .p ne se déclenche pas');
catch erreur
    assert(strcmp(erreur.identifier, 'sans_fonctions_p:appel'), 'piège : %s', erreur.message);
end
[nous, avions] = sans_fonctions_p(@() chaine_etudiants(S.buffers, refLon, refLat, seuil, Fse, Rs));

% contrôle statique : aucune .p parmi les fichiers dont dépend la chaîne
src = fullfile(dossier_projet(), 'src');
fichiers = matlab.codetools.requiredFilesAndProducts({ ...
    fullfile(src, 'General', 'process_buffer.m'), fullfile(src, 'General', 'update_liste_avion.m')});
% l'analyse dépend du chemin : sans les dossiers de la chaîne, elle ne
% trouverait rien, et l'absence de .p ne prouverait rien
assert(any(endsWith(fichiers, 'bit2registre.m')) && any(endsWith(fichiers, 'demodulatePPM.m')), ...
    'analyse des dépendances incomplète');
assert(~any(endsWith(fichiers, '.p')), 'la chaîne dépend de %s', strjoin(fichiers(endsWith(fichiers, '.p')), ', '));

%% 2) chaîne de référence, avec positions et bits
ref = [];
for b = 1:nb_buffers
    r = process_buffer_reference(S.buffers(:, b), refLon, refLat, seuil, Fse);
    [r.buf] = deal(b);
    ref = [ref, r]; %#ok<AGROW>
end
ref_err = arrayfun(@(r) r.registre.crcErrFlag, ref);
ref_valides = ref(ref_err == 0);

%% 3) comparaison message par message
ecart_pos = 1;
nous_cat = repmat({''}, 1, numel(nous));
ref_cat = repmat({''}, 1, numel(ref_valides));
for i = 1:numel(ref_valides)
    r = ref_valides(i);
    j = find([nous.buf] == r.buf & abs([nous.pos] - r.pos) <= ecart_pos ...
        & arrayfun(@(m) isequal(m.bits, r.bits), nous));
    if isempty(j)
        ref_cat{i} = 'manquant';
    elseif ~isempty(nous_cat{j})
        ref_cat{i} = 'doublon';     % deuxième déclenchement de la référence sur la même trame
    else
        ref_cat{i} = 'commun';
        nous_cat{j} = 'commun';
        meme_registre(nous(j).registre, r.registre);
    end
end
for j = find(cellfun(@isempty, nous_cat))
    % que fait la référence de ces bits ?
    m = nous(j);
    r = avec_reference(@() bit2registre_(m.bits, refLon, refLat));
    if isempty(r)
        nous_cat{j} = sprintf('FTC %d ignoré par la référence', m.registre.type);
    else
        nous_cat{j} = 'autre';
    end
end

nb_commun = sum(strcmp(ref_cat, 'commun'));
nb_doublon = sum(strcmp(ref_cat, 'doublon'));
nb_manquant = sum(strcmp(ref_cat, 'manquant'));
nb_autre = sum(strcmp(nous_cat, 'autre'));

%% 4) avions et positions
adr = @(liste) unique(arrayfun(@(x) hex2dec(x.registre.adresse), liste));
adr_nous = adr(nous);
adr_ref = adr(ref_valides);
est_position = @(liste) arrayfun(@(x) ~isempty(x.registre.latitude), liste);
pos_nous = sum(est_position(nous));
pos_ref = sum(est_position(ref_valides));
pos_ref_distinctes = sum(est_position(ref_valides(~strcmp(ref_cat, 'doublon'))));
manquent = setdiff(adr_ref, adr_nous);

%% 5) affichage
fprintf('  Référence : %d registres rendus, %d valides (%d trames distinctes, %d doublons), %d avions, %d positions\n', ...
    numel(ref), numel(ref_valides), numel(ref_valides) - nb_doublon, nb_doublon, numel(adr_ref), pos_ref);
fprintf('  Nous      : %d messages DF 17 valides, %d avions, %d positions\n', numel(nous), numel(adr_nous), pos_nous);
fprintf('  Communs : %d ; doublons de la référence : %d ; manquants : %d\n', nb_commun, nb_doublon, nb_manquant);
types = cellfun(@(c) c, nous_cat(~strcmp(nous_cat, 'commun')), 'UniformOutput', false);
[u, ~, idx] = unique(types);
for k = 1:numel(u)
    fprintf('  En plus chez nous : %3d  %s\n', sum(idx == k), u{k});
end
fprintf('\n  Écarts message par message (buffer, position, adresse, FTC, corrélation, trame) :\n');
for i = find(~strcmp(ref_cat, 'commun'))
    r = ref_valides(i);
    fprintf('  | référence | %s | %d | %d | %s | %d | %.3f | %s |\n', ref_cat{i}, r.buf, r.pos, ...
        r.registre.adresse, r.registre.type, r.corr, bits2hex(r.bits));
end
for j = find(~strcmp(nous_cat, 'commun'))
    m = nous(j);
    fprintf('  | nous | %s | %d | %d | %s | %d | %.3f | %s |\n', nous_cat{j}, m.buf, m.pos, ...
        m.registre.adresse, m.registre.type, m.corr, bits2hex(m.bits));
end
fprintf('\n  Avions (adresse, indicatif, messages, positions, altitude) :\n');
for a = adr_nous
    sel = nous(arrayfun(@(x) hex2dec(x.registre.adresse), nous) == a);
    noms = arrayfun(@(x) strtrim(char(x.registre.planeName)), sel, 'UniformOutput', false);
    noms = unique(noms(~cellfun(@isempty, noms)));
    alt = arrayfun(@(x) x.registre.altitude, sel(est_position(sel)));
    fprintf('  | %06X | %s | %d | %d | %s | %s |\n', a, strjoin(noms, ' '), numel(sel), sum(est_position(sel)), ...
        mat2str(unique([min(alt), max(alt)])), ternaire(ismember(a, adr_ref), 'oui', 'non'));
end

%% 6) cartes
sans_fonctions_p(@() tracer_carte(avions, refLon, refLat, false));
sauver_figure(gcf, 'tache8_carte');
close(gcf);
sans_fonctions_p(@() tracer_carte(avions, refLon, refLat, true));
title('Tâche 8 : tous les avions placés');
sauver_figure(gcf, 'tache8_carte_large');
close(gcf);

%% 7) vérifications
assert(nb_manquant == 0, '%d messages valides de la référence manquent', nb_manquant);
assert(nb_autre == 0, '%d messages en plus non expliqués', nb_autre);
assert(isempty(manquent), 'avions de la référence absents : %s', strjoin(cellstr(dec2hex(manquent, 6)), ' '));
assert(numel(adr_ref) == 23 && numel(ref_valides) == 93, 'la référence ne donne plus 23 avions et 93 messages');
% avions de la figure 1 du sujet
figure1 = {'0200AE', '4CA2AD', '4CA706', '394C0F', '346083', '3944E8', '405635', '4CA358', '407079'};
assert(all(ismember(hex2dec(figure1), adr_nous)), 'avions de la figure 1 absents');

res.nous = nous;
res.ref = ref_valides;
res.avions = avions;
res.chiffres = sprintf(['%d messages DF 17 valides, %d avions, %d positions ; référence : %d valides ' ...
    '(%d distincts + %d doublons), %d avions, %d positions (%d distinctes) ; %d/%d retrouvés, ' ...
    'aucune fonction .p appelée'], ...
    numel(nous), numel(adr_nous), pos_nous, numel(ref_valides), numel(ref_valides) - nb_doublon, nb_doublon, ...
    numel(adr_ref), pos_ref, pos_ref_distinctes, nb_commun + nb_doublon, numel(ref_valides));
fprintf('  Tâche 8 : %s\n', res.chiffres);
end

function [nous, avions] = chaine_etudiants(buffers, refLon, refLat, seuil, Fse, Rs)
% process_buffer puis update_liste_avion sur chaque buffer, comme adsb_app ;
% les bits de chaque message sont relus à sa position pour la comparaison.
    nous = struct('buf', {}, 'pos', {}, 'corr', {}, 'registre', {}, 'bits', {});
    avions = [];
    p = get_preamble(Fse);
    for b = 1:size(buffers, 2)
        [regs, corr, pos] = process_buffer(buffers(:, b), refLon, refLat, seuil, Fse);
        avions = update_liste_avion(avions, regs, '', Rs, b, corr, pos);
        y = abs(buffers(:, b).');
        for k = 1:numel(regs)
            bits = demodulatePPM(y(pos(k) + numel(p) + (0:112*Fse-1)), Fse);
            assert(isequaln(bit2registre(bits, refLon, refLat), regs{k}), 'bits relus incohérents');
            nous(end+1) = struct('buf', b, 'pos', pos(k), 'corr', corr(k), 'registre', regs{k}, 'bits', bits); %#ok<AGROW>
        end
    end
end

function tracer_carte(avions, refLon, refLat, large)
    affiche_carte(refLon, refLat);
    for a = avions
        plot(a);
    end
    if large
        x = []; y = [];
        for a = avions
            if ~isempty(a.trajectoire)
                x = [x, a.trajectoire(1, :)]; %#ok<AGROW>
                y = [y, a.trajectoire(2, :)]; %#ok<AGROW>
            end
        end
        xlim([min([x, -1.3581]) - 0.2, max([x, 0.7128]) + 0.4]);
        ylim([min([y, 44.4542]) - 0.2, max([y, 45.1683]) + 0.2]);
    end
    ecarter_etiquettes(avions);   % après les limites : la taille des textes en dépend
end

function meme_registre(a, b)
% mêmes champs ; l'adresse est comparée en nombre (la référence écrit
% '200AE' là où nous écrivons '0200AE')
    assert(hex2dec(a.adresse) == hex2dec(b.adresse), 'adresse %s / %s', a.adresse, b.adresse);
    for c = {'format', 'type', 'planeName', 'altitude', 'cprf', 'crcErrFlag'}
        assert(isequal(a.(c{1}), b.(c{1})) || (isempty(a.(c{1})) && isempty(b.(c{1}))), ...
            '%s : champ %s différent de la référence', a.adresse, c{1});
    end
    for c = {'latitude', 'longitude'}
        assert(isequal(size(a.(c{1})), size(b.(c{1}))) && all(abs(a.(c{1}) - b.(c{1})) < 1e-9), ...
            '%s : champ %s différent de la référence', a.adresse, c{1});
    end
end

function h = bits2hex(bits)
    h = dec2hex(bin2dec(reshape(char(bits + '0'), 4, []).')).';
end

function s = ternaire(c, a, b)
    if c
        s = a;
    else
        s = b;
    end
end
