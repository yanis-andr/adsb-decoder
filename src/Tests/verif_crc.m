function res = verif_crc()
% encodeCRC / decodeCRC contre encodeCRC_ / decodeCRC_ :
% vecteurs ligne et colonne, trames intègres et trames corrompues
% (0 à 3 bits inversés au hasard parmi les 112).

rng(31);
N = 300;
messages = randi([0 1], N, 88);
n_inv = mod(1:N, 4);
positions = cell(1, N);
for k = 1:N
    positions{k} = randperm(112, n_inv(k));
end

% référence, en un seul passage (changer de chemin coûte cher)
[c_ref, d_ref, e_ref, d_ref_col, e_ref_col] = avec_reference(@() reference(messages, positions));

nb_err_ref = 0;   % désaccords avec la référence
nb_detect = 0;    % trames corrompues détectées
for k = 1:N
    b = messages(k, :);

    % codage, ligne et colonne
    c = encodeCRC(b);
    c_col = encodeCRC(b(:));
    assert(isrow(c) && iscolumn(c_col), 'encodeCRC : forme de sortie');
    assert(isequal(double(c), double(c_ref{k}(:).')) && isequal(c_col, c(:)), ...
        'encodeCRC différent de encodeCRC_ (trame %d)', k);

    % décodage de la trame corrompue, ligne et colonne
    r = c;
    r(positions{k}) = 1 - r(positions{k});
    [d, e] = decodeCRC(r);
    [d_col, e_col] = decodeCRC(r(:));
    assert(isequal(size(d), size(d_ref{k})) && isequal(size(d_col), size(d_ref_col{k})), ...
        'decodeCRC : forme de sortie');
    assert(isequal(double(d), double(d_ref{k})) && isequal(double(d_col), double(d_ref_col{k})), ...
        'decodeCRC : bits différents');
    nb_err_ref = nb_err_ref + (e ~= e_ref(k)) + (e_col ~= e_ref_col(k));

    if n_inv(k) == 0
        assert(e == 0, 'trame intègre déclarée corrompue');
    else
        nb_detect = nb_detect + e;
    end
end

assert(nb_err_ref == 0, '%d décisions différentes de decodeCRC_', nb_err_ref);
n_corrompues = sum(n_inv > 0);
assert(nb_detect == n_corrompues, 'corruptions détectées : %d / %d', nb_detect, n_corrompues);

res.chiffres = sprintf('%d trames x 2 formes identiques à la référence ; %d/%d corruptions détectées', ...
    N, nb_detect, n_corrompues);
fprintf('  CRC : %s\n', res.chiffres);
end

function [c_ref, d_ref, e_ref, d_ref_col, e_ref_col] = reference(messages, positions)
    N = size(messages, 1);
    c_ref = cell(1, N); d_ref = cell(1, N); d_ref_col = cell(1, N);
    e_ref = zeros(1, N); e_ref_col = zeros(1, N);
    for k = 1:N
        c_ref{k} = encodeCRC_(messages(k, :));
        r = c_ref{k}(:).';
        r(positions{k}) = 1 - r(positions{k});
        [d_ref{k}, e_ref(k)] = decodeCRC_(r);
        [d_ref_col{k}, e_ref_col(k)] = decodeCRC_(r(:));
    end
end
