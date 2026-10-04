function [n] = cprNL(lat)
    % accepte un scalaire ou un vecteur ; la sortie a la forme de l'entrée
    n = zeros(size(lat));
    for k = 1:numel(lat)
        n(k) = cprNL_scalaire(lat(k));
    end
end

function [n] = cprNL_scalaire(lat)

    % Cas particuliers
    if abs(lat) < 0.0001  % lat ~ 0
        n = 59;
        return;
    end
    
    if abs(abs(lat) - 87) < 0.0001  % lat ~ 87 ou -87
        n = 2;
        return;
    end
    
    if abs(lat) > 87
        n = 1;
        return;
    end
    NZ = 15;
    
    numerator = 1 - cos(pi / (2 * NZ));
    denominator = cos(pi * abs(lat) / 180)^2;
    
    if denominator == 0
        n = 1;
        return;
    end
    
    inner = 1 - numerator / denominator;
    
    % Vérifier qu'on est dans [-1, 1] (sinon probleme pour arccos)
    if inner < -1
        inner = -1;
    elseif inner > 1
        inner = 1;
    end
    
    n = floor((2 * pi) / acos(inner));
    
end
