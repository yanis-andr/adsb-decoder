function dossier = chemin_reference()
% Dossier de fonctions-relais vers les fonctions .p du professeur.
% Les .p appellent les noms sans "_" (decodeCRC, cprNL, ...) : sans relais,
% la "référence" passerait par notre code. Ce dossier, placé en tête du
% chemin, redirige chaque nom vers sa version "_".
% Usage : d = chemin_reference(); addpath(d,'-begin'); ... ; rmpath(d);
% (puis "clear functions" pour revenir à nos fonctions).

    % dans tempdir, hors du dépôt : ces relais sont générés, jamais versionnés,
    % et réécrits seulement s'ils manquent ou ont changé
    dossier = fullfile(tempdir, 'adsb_reference');
    if ~exist(dossier, 'dir')
        mkdir(dossier);
    end

    % nom, liste des sorties, liste des entrées
    relais = {
        'modulatePPM',     'y',                  'x, Fse'
        'demodulatePPM',   'b',                  'x, Fse'
        'get_preamble',    'p',                  'Fse'
        'encodeCRC',       'c',                  'b'
        'decodeCRC',       '[b, err]',           'c'
        'Mon_Welch',       '[X, f]',             'x, Nfft, Fe'
        'bit2registre',    'reg',                'b, refLon, refLat'
        'cpr2LatLon',      '[lon, lat]',         'regLAT, regLON, CPRF, refLat, refLon'
        'cprMod',          'r',                  'a, b'
        'cprNL',           'n',                  'lat'
        'process_buffer',  '[reg, corr]',        'buf, refLon, refLat, seuil, Fse'
        'update_liste_avion', 'l',               'l, reg, mask, Rs, n, corr'
    };

    nouveau = false;
    for k = 1:size(relais, 1)
        nom = relais{k, 1};
        contenu = sprintf('function %s = %s(%s)\n    %s = %s_(%s);\nend\n', ...
            relais{k, 2}, nom, relais{k, 3}, relais{k, 2}, nom, relais{k, 3});
        fichier = fullfile(dossier, [nom '.m']);
        % réécrit seulement si absent ou différent (réécrire force un rehash lent)
        if ~exist(fichier, 'file') || ~strcmp(fileread(fichier), contenu)
            fid = fopen(fichier, 'w');
            fprintf(fid, '%s', contenu);
            fclose(fid);
            nouveau = true;
        end
    end
    if nouveau
        rehash;
    end
end
