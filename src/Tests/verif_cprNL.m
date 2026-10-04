function res = verif_cprNL()
% cprNL contre cprNL_ (appelée élément par élément) : scalaires,
% vecteurs ligne et colonne.
% Seul écart admis : |lat| = 87, où le sujet (annexe) donne NL = 2
% alors que cprNL_ renvoie 1.

rng(32);
lat = [-90 + 180*rand(1, 5000), 0, 10, 45, 86.9, 87.1, -87.1, 89.9];
lat = lat(abs(abs(lat) - 87) > 1e-4);

n = cprNL(lat);
n_col = cprNL(lat(:));
% cprNL_ n'est pas vectorielle (un vecteur donne un seul nombre) :
% référence prise élément par élément
n_ref = avec_reference(@() arrayfun(@cprNL_, lat));
assert(isequal(size(n), size(lat)) && iscolumn(n_col), 'cprNL : forme de sortie');
assert(isequal(n, n_ref) && isequal(n_col, n(:)), ...
    'cprNL différent de cprNL_ sur %d latitudes', sum(n ~= n_ref));

% scalaires, un par un
for k = 1:20:numel(lat)
    assert(cprNL(lat(k)) == n_ref(k), 'cprNL scalaire différent');
end

% écart connu à 87 degrés
assert(cprNL(87) == 2 && cprNL(-87) == 2, 'NL(87) doit valoir 2 (sujet)');

res.chiffres = sprintf('%d latitudes identiques à cprNL_ (ligne, colonne, scalaire) ; NL(87) = 2 comme le sujet', ...
    numel(lat));
fprintf('  cprNL : %s\n', res.chiffres);
end
