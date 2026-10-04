function varargout = sans_fonctions_p(f)
% Évalue f() en interdisant les fonctions .p de l'enseignant.
% Pour chaque fichier .p de src/, une fonction piège du même nom, placée en
% tête du chemin, lève l'erreur 'sans_fonctions_p:appel' si elle est
% appelée : f() échoue dès que la chaîne appelle une .p, même indirectement.
% Exemple : regs = sans_fonctions_p(@() process_buffer(buf, lon, lat, 0.75, 4));
    dossier = fullfile(tempdir, 'adsb_pieges_p');
    if ~exist(dossier, 'dir')
        mkdir(dossier);
    end
    noms = noms_fonctions_p();
    for k = 1:numel(noms)
        contenu = sprintf(['function varargout = %s(varargin) %%#ok<STOUT>\n' ...
            '    error(''sans_fonctions_p:appel'', ''appel à la fonction .p %s'');\n' ...
            'end\n'], noms{k}, noms{k});
        fichier = fullfile(dossier, [noms{k} '.m']);
        if ~exist(fichier, 'file') || ~strcmp(fileread(fichier), contenu)
            fid = fopen(fichier, 'w');
            fprintf(fid, '%s', contenu);
            fclose(fid);
            rehash;
        end
    end

    addpath(dossier, '-begin');
    try
        [varargout{1:nargout}] = f();
    catch erreur
        rmpath(dossier);
        rethrow(erreur);
    end
    rmpath(dossier);
end

function noms = noms_fonctions_p()
    fichiers = dir(fullfile(dossier_projet(), 'src', '**', '*.p'));
    noms = unique(erase({fichiers.name}, '.p'));
end
