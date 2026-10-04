% Lance toutes les vérifications du projet ADS-B, dans l'ordre :
%  1) nos blocs contre les fonctions .p de l'enseignant (entrées fixées
%     et bruitées) ;
%  2) les scripts des tâches 1, 2, 3, 4 et 6 (figures dans docs/figures) ;
%  3) les tâches 8 et 9 sur les enregistrements réels : notre chaîne contre
%     celle de l'enseignant, message par message, sans aucune fonction .p,
%     puis le rejeu des 9 buffers dans adsb_app.
% task8_seuil (analyse du seuil, une minute environ) se lance à part.
% S'arrête au premier échec (erreur, donc code de sortie non nul en mode
% batch) et affiche un résumé chiffré.
% Depuis la racine du dépôt :
%   matlab -batch "run('src/Tests/main_tests.m')"

clear; close all;

dossier_tests = fileparts(mfilename('fullpath'));
src = fileparts(dossier_tests);
addpath(fullfile(src, 'PHY'), fullfile(src, 'MAC'), fullfile(src, 'General'), dossier_tests);
if batchStartupOptionUsed
    set(groot, 'DefaultFigureVisible', 'off');
end

etapes = {
    'verif_crc',            'encodeCRC / decodeCRC contre la référence'
    'verif_cprNL',          'cprNL contre la référence'
    'verif_modulatePPM',    'modulatePPM et préambule contre la référence'
    'verif_demodulatePPM',  'demodulatePPM contre la référence'
    'verif_bit2registre',   'bit2registre contre la référence'
    'verif_Mon_Welch',      'Mon_Welch contre la référence'
    'test_task1_basic',     'Tâche 1 ST4 : aller-retour PPM'
    'test_task1_st5',       'Tâche 1 ST5 : allures s_l, r_l, r_m'
    'test_task1_ber',       'Tâche 1 ST6 : TEB contre théorie'
    'test_task2_dsp',       'Tâche 2 ST6 : DSP estimée contre analytique'
    'test_task3_crc',       'Tâche 3 : CRC dans la chaîne'
    'test_task4_sync',      'Tâche 4 ST5-ST6 : synchronisation'
    'test_task4_ber_sync',  'Tâche 4 ST7 : TEB et perte à 1e-3'
    'test_task6_mac',       'Tâche 6 ST3 : adsb_msgs.mat et trajectoire'
    'task8',                'Tâche 8 : buffers.mat contre la référence, sans .p'
    'test_task9_rejeu',     'Tâche 9 : rejeu des buffers dans adsb_app'
};

n = size(etapes, 1);
resume = cell(0, 3);
echec = [];
fprintf('=== ADS-B : %d vérifications ===\n', n);
t_total = tic;
for k = 1:n
    nom = etapes{k, 1};
    fprintf('\n[%2d/%d] %s (%s)\n', k, n, etapes{k, 2}, nom);
    t0 = tic;
    try
        res = feval(nom);
        resume(end+1, :) = {nom, toc(t0), res.chiffres}; %#ok<SAGROW>
    catch erreur
        echec = struct('nom', nom, 'message', erreur.message, 'duree', toc(t0));
    end
    close all;
    if ~isempty(echec)
        break;
    end
end

fprintf('\n=== Résumé ===\n');
for k = 1:size(resume, 1)
    fprintf('OK     %-20s %6.1f s  %s\n', resume{k, 1}, resume{k, 2}, resume{k, 3});
end
if ~isempty(echec)
    fprintf('ÉCHEC  %-20s %6.1f s  %s\n', echec.nom, echec.duree, echec.message);
    fprintf('%d/%d vérifications passées, arrêt au premier échec (%.0f s).\n', ...
        size(resume, 1), n, toc(t_total));
    error('main_tests:echec', 'Échec de %s : %s', echec.nom, echec.message);
end
fprintf('%d/%d vérifications passées en %.0f s.\n', n, n, toc(t_total));
