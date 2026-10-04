function [ listOfPlanes ] = update_liste_avion(listOfPlanes, liste_new_registre, DISPLAY_MASK, Rs, n, liste_corrVal, positions)
% Met à jour la liste des avions (objets Avion) avec les registres d'un buffer
% et affiche une ligne par registre.
%  DISPLAY_MASK : format d'une ligne (vide : rien n'est affiché) ;
%  Rs : fréquence d'échantillonnage ; n : numéro du buffer ;
%  liste_corrVal : corrélation du préambule de chaque registre ;
%  positions (facultatif) : début de chaque trame dans le buffer, en
%  échantillons, pour afficher sa date t dans le buffer.
% Seuls les registres à CRC bon mettent à jour un avion ; un avion est créé
% à la première trame valide de son adresse.
    if nargin < 7
        positions = [];
    end

    for k = 1:numel(liste_new_registre)
        reg = liste_new_registre{k};

        if ~isempty(DISPLAY_MASK)
            afficher(reg, DISPLAY_MASK, Rs, n, liste_corrVal, positions, k);
        end
        if reg.crcErrFlag || reg.format ~= 17
            continue;
        end

        adresse = ['0x', reg.adresse];
        avion = [];
        for a = listOfPlanes
            if strcmp(a.adresse, adresse)
                avion = a;
                break;
            end
        end
        if isempty(avion)
            avion = Avion('');
            avion.setAdresse(adresse);
            avion.displayLogo = false;   % imrotate : Image Processing Toolbox absente
            avion.setStyle(numel(listOfPlanes) + 1);
            listOfPlanes = [listOfPlanes, avion]; %#ok<AGROW>
        end

        % une position sans latitude (FTC non décodé) ne peut pas être placée
        position = reg.type >= 5 && reg.type <= 18;
        if ~position || ~isempty(reg.latitude)
            avion.updateWithRegister(reg);
        end
    end
end

function afficher(reg, DISPLAY_MASK, Rs, n, corr, positions, k)
    texte = @(x) num2str(x);
    t = '';
    if numel(positions) >= k
        t = sprintf('%.6f', (positions(k) - 1) / Rs);
    end
    c = '';
    if numel(corr) >= k
        c = sprintf('%.4f', corr(k));
    end
    crc = 'OK';
    if reg.crcErrFlag
        crc = 'KO';
    end
    fprintf(DISPLAY_MASK, texte(n), t, c, texte(reg.format), reg.adresse, texte(reg.type), ...
        char(reg.planeName), texte(reg.altitude), texte(reg.cprf), ...
        texte(reg.longitude), texte(reg.latitude), crc);
end
