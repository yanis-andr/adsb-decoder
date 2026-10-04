function ecarter_etiquettes(listOfPlanes)
% Écarte verticalement les étiquettes des avions qui se chevauchent sur la
% carte (Avion.plot les pose toutes juste au-dessus de l'avion). Seule la
% position des textes change : avions et trajectoires restent en place.
% À appeler après plot de chaque avion.
    h = [];
    for a = listOfPlanes
        if ~isempty(a.handleTextPlane) && isvalid(a.handleTextPlane)
            h = [h, a.handleTextPlane]; %#ok<AGROW>
        end
    end
    if numel(h) < 2
        return;
    end
    drawnow;   % Extent n'est à jour qu'une fois le texte dessiné

    % du bas vers le haut : chaque étiquette monte au-dessus de celles,
    % déjà placées, qu'elle chevauche
    y = arrayfun(@(t) t.Position(2), h);
    [~, ordre] = sort(y);
    h = h(ordre);
    marge = 0.002 * diff(ylim(gca));
    for k = 2:numel(h)
        for essai = 1:numel(h)
            e = h(k).Extent;   % [x y largeur hauteur]
            bouge = false;
            for j = 1:k-1
                f = h(j).Extent;
                if e(1) < f(1) + f(3) && f(1) < e(1) + e(3) && e(2) < f(2) + f(4) && f(2) < e(2) + e(4)
                    h(k).Position(2) = h(k).Position(2) + (f(2) + f(4) - e(2)) + marge;
                    bouge = true;
                    break;
                end
            end
            if ~bouge
                break;
            end
        end
    end
end
