function [preamble] = get_preamble(Fse)
    % impulsions à 0 ; 1 ; 3,5 et 4,5 µs (-1 : pas d'impulsion)
    preamble = modulatePPM([1 1 -1 0 0 -1 -1 -1], Fse);
end

