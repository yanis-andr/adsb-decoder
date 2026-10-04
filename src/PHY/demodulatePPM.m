function bits = demodulatePPM(packet,Fse)
    % filtre adapté (somme sur chaque demi-symbole) puis décision
    % signal réel : maximum de vraisemblance r1 > r2 (tâche 1, ST3)
    % signal complexe (phase inconnue) : |r1| > |r2| (tâche 4, ST4)
    packet = packet(:).';
    bits = zeros(1, length(packet)/Fse);
    mid = Fse/2;

    for k=1:length(packet)/Fse
        packet_k = packet((k-1)*Fse + (1:Fse));

        % integrate each half
        r1 = sum(packet_k(1:mid));
        r2 = sum(packet_k(mid+1:end));

        % bit 1 si l'impulsion est dans la première moitié
        % isreal teste le type, pas les valeurs : un tableau complexe dont
        % la partie imaginaire est nulle passe par |r1| > |r2|, qui donne
        % la même décision que r1 > r2 si les échantillons sont positifs
        % (enveloppe), mais pas en général
        if isreal(packet)
            bits(k) = (r1 > r2);
        else
            bits(k) = (abs(r1) > abs(r2));
        end
    end
end
