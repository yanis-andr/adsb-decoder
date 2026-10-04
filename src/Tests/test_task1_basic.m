function res = test_task1_basic()
% Tâche 1 ST4 : aller-retour modulation / démodulation PPM sans bruit
% (Fe = 20 MHz, Fse = 20), sur une séquence fixe et des séquences aléatoires.

Fe = 20e6;
Rb = 1e6;
Fse = floor(Fe/Rb);

% séquence fixe
b = [1 0 0 1 0 0 0 1 1 0 1];
sl = modulatePPM(b, Fse);
assert(length(sl) == length(b)*Fse, 'longueur du signal modulé');
assert(isequal(demodulatePPM(sl, Fse), b), 'aller-retour faux sur la séquence fixe');

% séquences aléatoires
rng(12);
nb_err = 0;
for k = 1:100
    b = randi([0 1], 1, 112);
    nb_err = nb_err + sum(demodulatePPM(modulatePPM(b, Fse), Fse) ~= b);
end
assert(nb_err == 0, '%d erreurs sans bruit', nb_err);

res.chiffres = sprintf('0 erreur sans bruit (1 séquence fixe de 11 bits, 100 trames de 112 bits)');
fprintf('  Tâche 1 ST4 : %s\n', res.chiffres);
end
