function varargout = avec_reference(f)
% Évalue f() avec les relais vers les fonctions .p en tête du chemin,
% puis rend la main à nos fonctions.
% Exemple : [b, err] = avec_reference(@() decodeCRC_(c));
    d = chemin_reference();
    addpath(d, '-begin');
    try
        [varargout{1:nargout}] = f();
    catch erreur
        rmpath(d);
        rethrow(erreur);
    end
    rmpath(d);
end
