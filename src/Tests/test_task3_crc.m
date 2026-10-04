function res = test_task3_crc()
% Tâche 3 : chaîne de la figure 2 (88 bits -> CRC -> 112 bits -> PPM ->
% démodulation -> décodage CRC). Le décodeur doit dire « intègre » sans
% erreur et « non intègre » dès qu'un des 88 bits utiles est faux.

rng(13);
Fse = 20;
Nb = 88;  % ADS-B payload size

% sans erreur
nb_faux_negatif = 0;
for k = 1:200
    b = randi([0,1], 1, Nb);
    c = encodeCRC(b);
    [b_hat, error_flag] = decodeCRC(demodulatePPM(modulatePPM(c, Fse), Fse));
    assert(isequal(b_hat, b), 'bits utiles mal retrouvés');
    nb_faux_negatif = nb_faux_negatif + error_flag;
end
assert(nb_faux_negatif == 0, '%d trames intègres déclarées fausses', nb_faux_negatif);

% une erreur parmi les 88 bits utiles, à chaque position
nb_detect = 0;
b = randi([0,1], 1, Nb);
c = encodeCRC(b);
for idx_error = 1:Nb
    r = c;
    r(idx_error) = 1 - r(idx_error);
    [~, error_flag] = decodeCRC(r);
    nb_detect = nb_detect + error_flag;
end
assert(nb_detect == Nb, 'erreurs détectées : %d / %d', nb_detect, Nb);

res.chiffres = sprintf('200 trames sans erreur : 0 fausse alarme ; 1 bit faux à chacune des 88 positions : %d/88 détectés', nb_detect);
fprintf('  Tâche 3 : %s\n', res.chiffres);
end
