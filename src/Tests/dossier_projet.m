function racine = dossier_projet()
% Racine du dépôt (contient src/, data/, docs/), quel que soit le dossier courant.
    racine = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
