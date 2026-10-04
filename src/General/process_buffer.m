function [liste_new_registre, corrVal, positions] = process_buffer(cplxBuffer, REF_LON, REF_LAT, seuilDetection, Fse)
% Décode toutes les trames ADS-B d'un buffer complexe (radio à Fe = Fse·Rb).
%  1) enveloppe |y| : la phase et le décalage en fréquence ne comptent plus ;
%  2) corrélation normalisée avec le préambule, sur tout le buffer d'un coup ;
%  3) candidats : maxima locaux de la corrélation au-dessus du seuil ;
%  4) pour chaque candidat : démodulation des 112 bits, CRC, registre.
% Rend les registres ADS-B (DF 17) à CRC bon, au format de bit2registre,
% la corrélation de leur préambule et la position du début du préambule
% dans le buffer (en échantillons, à partir de 1).
% Seul DF 17 est gardé : un candidat placé un bit trop tôt lit un 0 de plus
% en tête de la trame ; si son dernier bit vaut 0, le mot décalé est encore
% un multiple du polynôme générateur et le CRC passe. Ce faux message
% commence par 0, donc par un DF inférieur à 16.
% Une même trame peut donner deux candidats voisins (palier de la
% corrélation à 4 MHz) : une trame identique qui chevauche la précédente
% est un doublon et n'est gardée qu'une fois.

    y = abs(cplxBuffer(:).');
    p = get_preamble(Fse);
    Lp = length(p);
    Ltrame = 112 * Fse;
    N = length(y);

    % rho(k) = <y(k:k+Lp-1), p> / (||p|| · ||y(k:k+Lp-1)||)
    num = conv(y, fliplr(p), 'valid');
    energie = movsum(y.^2, [0 Lp-1]);
    energie = energie(1:N-Lp+1);
    rho = zeros(1, N-Lp+1);
    ok = energie > 0;
    rho(ok) = num(ok) ./ sqrt(sum(p.^2) * energie(ok));

    % maxima locaux (paliers compris) au-dessus du seuil, trame entière dans le buffer
    kmax = N - Lp - Ltrame + 1;
    voisin_g = [-Inf, rho(1:end-1)];
    voisin_d = [rho(2:end), -Inf];
    candidats = find(rho >= seuilDetection & rho >= voisin_g & rho >= voisin_d);
    candidats = candidats(candidats <= kmax);

    liste_new_registre = {};
    corrVal = [];
    positions = [];
    derniers_bits = [];
    fin_derniere = 0;
    for k = candidats
        bits = demodulatePPM(y(k+Lp : k+Lp+Ltrame-1), Fse);
        registre = bit2registre(bits, REF_LON, REF_LAT);
        if registre.crcErrFlag || registre.format ~= 17
            continue;
        end
        if k < fin_derniere && isequal(bits, derniers_bits)
            continue;   % doublon de la trame précédente
        end
        liste_new_registre{end+1} = registre; %#ok<AGROW>
        corrVal(end+1) = rho(k); %#ok<AGROW>
        positions(end+1) = k; %#ok<AGROW>
        derniers_bits = bits;
        fin_derniere = k + Lp + Ltrame;
    end
end
