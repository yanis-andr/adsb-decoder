function res = test_task9_rejeu()
% Tâche 9 sans la radio : adsb_app('rejeu') lit les 9 buffers enregistrés,
% un toutes les 0,5 s à la place de get_buffer, et met à jour la liste des
% avions et la carte après chaque buffer, comme en direct.
% Vérifie : aucune fonction .p appelée (pièges) ni requise (dépendances) ;
% un buffer toutes les 0,5 s (cadence d'un flux continu, plus rapide que
% les enregistrements, espacés d'environ 10 à 16 s) ;
% chaque buffer traité en moins de 0,5 s (sinon le direct prendrait du
% retard) ; mêmes avions et mêmes trajectoires que le décodage hors ligne.
% Figure : docs/figures/tache9_rejeu.png (carte après 3 buffers sur 9 ; la
% carte finale est celle de la tâche 8).

addpath(fileparts(fileparts(mfilename('fullpath'))), '-end');   % src/, pour adsb_app
% étape intermédiaire : la carte après 3 buffers
[avions3, ~] = sans_fonctions_p(@() rejeu_sous_pieges(3));
fig = figure(1);
title(sprintf('Rejeu : carte après 3 buffers sur 9 (%d avions)', numel(avions3)));
sauver_figure(fig, 'tache9_rejeu');

t0 = tic;
[avions, durees] = sans_fonctions_p(@() rejeu_sous_pieges(Inf));
duree_totale = toc(t0);

S = load(fullfile(dossier_projet(), 'data', 'buffers.mat'), 'buffers', 'Rs');
nb = size(S.buffers, 2);
duree_buffer = size(S.buffers, 1) / S.Rs;
assert(numel(durees) == nb, '%d buffers traités au lieu de %d', numel(durees), nb);
assert(duree_totale >= (nb - 1) * duree_buffer, 'rejeu trop rapide : %.2f s', duree_totale);
assert(max(durees) < duree_buffer, 'traitement d''un buffer en %.2f s, plus que %.1f s', max(durees), duree_buffer);

% décodage hors ligne des mêmes buffers
attendus = [];
for b = 1:nb
    [regs, corr, pos] = process_buffer(S.buffers(:, b), -0.606629, 44.806884, 0.75, S.Rs / 1e6);
    attendus = update_liste_avion(attendus, regs, '', S.Rs, b, corr, pos);
end
assert(numel(avions) == numel(attendus), '%d avions au lieu de %d', numel(avions), numel(attendus));
for k = 1:numel(avions)
    assert(strcmp(avions(k).adresse, attendus(k).adresse) && isequal(avions(k).nom, attendus(k).nom) ...
        && isequal(avions(k).trajectoire, attendus(k).trajectoire), 'avion %s différent', avions(k).adresse);
end
places = sum(arrayfun(@(a) ~isempty(a.longitude), avions));
assert(numel(avions3) < numel(avions), 'la carte intermédiaire devrait avoir moins d''avions');

% contrôle statique : aucune .p parmi les fichiers dont dépend adsb_app
fichiers = matlab.codetools.requiredFilesAndProducts(which('adsb_app'));
assert(any(endsWith(fichiers, 'get_buffer_rejeu.m')), 'analyse des dépendances incomplète');
assert(~any(endsWith(fichiers, '.p')), 'adsb_app dépend de %s', strjoin(fichiers(endsWith(fichiers, '.p')), ', '));

res.chiffres = sprintf('%d buffers en %.1f s (un toutes les %.1f s), traitement de %.2f à %.2f s par buffer, %d avions dont %d placés (%d après 3 buffers)', ...
    nb, duree_totale, duree_buffer, min(durees), max(durees), numel(avions), places, numel(avions3));
fprintf('  Tâche 9 : %s\n', res.chiffres);
end

function [avions, durees] = rejeu_sous_pieges(nb_buffers)
% adsb_app ajoute ses dossiers au chemin : les pièges doivent rester devant
    [avions, durees] = adsb_app('rejeu', nb_buffers);
    assert(contains(which('process_buffer_'), 'adsb_pieges_p'), 'les pièges des .p ne sont plus en tête du chemin');
end
