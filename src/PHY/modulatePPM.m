function modSig = modulatePPM(sig, Fse)
    % 1 -> impulsion en début de symbole, 0 -> en fin de symbole,
    % -1 -> pas d'impulsion (sert à construire le préambule)
    p1 = [ones(1,Fse/2), zeros(1,Fse/2)];
    p0 = [zeros(1,Fse/2), ones(1,Fse/2)];
    pvide = zeros(1,Fse);

    modSig = zeros(1, length(sig)*Fse);
    for i = 1:length(sig)
        if sig(i) == 0
            p = p0;
        elseif sig(i) == -1
            p = pvide;
        else
            p = p1;
        end
        modSig((i-1)*Fse + (1:Fse)) = p;
    end
end
