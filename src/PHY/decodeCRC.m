
function [decodedBits,error] = decodeCRC(bits)
    % accepte un vecteur ligne ou colonne ; la sortie garde la même forme
    colonne = iscolumn(bits);
    bits = bits(:).';
    buff = bits;
    error = 0;

    crc_poly = [1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,0,0,0,0,0,0,1,0,0,1];
    crc_poly_deg = length(crc_poly) - 1;
    for i = 1:(length(bits) - crc_poly_deg)
        if buff(i) == 1
            buff(i:i + crc_poly_deg) = xor(buff(i:i + crc_poly_deg), crc_poly);
        end
    end
    reste = buff(end - crc_poly_deg+ 1 : end);
    %disp(reste);
    for i=1:crc_poly_deg
        if reste(i) ~= 0
            error = 1;
            break;
        end
    end
    decodedBits = bits(1:end - crc_poly_deg);
    if colonne
        decodedBits = decodedBits(:);
    end
end


