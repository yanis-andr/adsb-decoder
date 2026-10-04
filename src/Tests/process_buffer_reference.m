function ref = process_buffer_reference(buffer, refLon, refLat, seuil, Fse)
% Chaîne de l'enseignant (process_buffer_ et ses blocs .p) sur un buffer,
% avec, pour chaque registre rendu, sa position et ses 112 bits.
% process_buffer_ ne rend ni l'une ni les autres : un relais de bit2registre
% note les bits de chaque appel, et les candidats de la référence sont tous
% les échantillons où la corrélation normalisée dépasse le seuil, dans
% l'ordre (vérifié : même nombre d'appels, mêmes corrélations).
% Sortie : tableau de structures (registre, corr, pos, bits), pos = début
% du préambule dans le buffer.

    global JOURNAL_BITS %#ok<GVMIS>
    JOURNAL_BITS = cell(0, 2);

    % relais : les noms sans "_" vers la référence, bit2registre noté
    dossier = fullfile(tempdir, 'adsb_reference_journal');
    if ~exist(dossier, 'dir')
        mkdir(dossier);
    end
    d_ref = chemin_reference();
    for f = dir(fullfile(d_ref, '*.m'))'
        if ~strcmp(f.name, 'bit2registre.m')
            copier_si_different(fullfile(d_ref, f.name), fullfile(dossier, f.name));
        end
    end
    contenu = sprintf(['function reg = bit2registre(b, refLon, refLat)\n' ...
        '    global JOURNAL_BITS %%#ok<GVMIS>\n' ...
        '    reg = bit2registre_(b, refLon, refLat);\n' ...
        '    JOURNAL_BITS(end+1, :) = {b(:).'', reg};\n' ...
        'end\n']);
    ecrire_si_different(fullfile(dossier, 'bit2registre.m'), contenu);

    addpath(dossier, '-begin');
    try
        [regs, corr] = process_buffer_(buffer(:).', refLon, refLat, seuil, Fse);
    catch erreur
        rmpath(dossier);
        rethrow(erreur);
    end
    rmpath(dossier);

    % candidats de la référence : rho >= seuil, avec notre corrélation
    y = abs(buffer(:).');
    p = get_preamble(Fse);   % identique à get_preamble_ (verif_modulatePPM)
    num = conv(y, fliplr(p), 'valid');
    energie = movsum(y.^2, [0 length(p)-1]);
    energie = energie(1:length(num));
    rho = num ./ sqrt(sum(p.^2) * energie);
    candidats = find(rho >= seuil);
    assert(numel(candidats) == size(JOURNAL_BITS, 1), ...
        'référence : %d appels pour %d candidats', size(JOURNAL_BITS, 1), numel(candidats));

    % chaque registre rendu vient du premier appel suivant qui le redonne
    ref = struct('registre', {}, 'corr', {}, 'pos', {}, 'bits', {});
    i = 1;
    for j = 1:numel(regs)
        while true
            assert(i <= size(JOURNAL_BITS, 1), 'registre %d de la référence introuvable', j);
            if isequaln(JOURNAL_BITS{i, 2}, regs{j})
                break;
            end
            i = i + 1;
        end
        assert(abs(rho(candidats(i)) - corr(j)) < 1e-9, 'corrélation différente de la référence');
        ref(j) = struct('registre', regs{j}, 'corr', corr(j), 'pos', candidats(i), 'bits', JOURNAL_BITS{i, 1});
        i = i + 1;
    end
    clear global JOURNAL_BITS
end

function copier_si_different(source, cible)
    ecrire_si_different(cible, fileread(source));
end

function ecrire_si_different(fichier, contenu)
    if ~exist(fichier, 'file') || ~strcmp(fileread(fichier), contenu)
        fid = fopen(fichier, 'w');
        fprintf(fid, '%s', contenu);
        fclose(fid);
        rehash;
    end
end
