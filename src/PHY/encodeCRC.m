function [encodedBits] = encodeCRC(bits)
    % accepte un vecteur ligne ou colonne ; la sortie garde la même forme
    colonne = iscolumn(bits);
    bits = bits(:).';

    crc_poly = [1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,0,0,0,0,0,0,1,0,0,1];
    crc_poly_deg = length(crc_poly) - 1;
    encodedBits = [];
    full_bits = [bits, zeros(1, crc_poly_deg)];
    for i=1:length(bits)
        if full_bits(i) == 1
            full_bits(i:i + crc_poly_deg) = xor(full_bits(i:i + crc_poly_deg), crc_poly);
        end
    end
    reste = full_bits(end-(crc_poly_deg-1) : end);
    encodedBits = [bits reste];
    if colonne
        encodedBits = encodedBits(:);
    end
end