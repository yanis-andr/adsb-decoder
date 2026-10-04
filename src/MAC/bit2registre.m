function registre = bit2registre(bitPacketCRC, refLon, refLat)
    % Champs du registre : ceux qu'attendent update_liste_avion et Avion
    % (planeName, cprf, crcErrFlag, adresse en hexadécimal).
    % Le registre est toujours rendu ; crcErrFlag = 1 s'il faut l'ignorer.
    registre = struct('format', [], 'adresse', [], 'type', [], 'planeName', [], ...
                      'altitude', [], 'cprf', [], ...
                      'latitude', [], 'longitude', [], 'crcErrFlag', []);

    bitPacketCRC = bitPacketCRC(:).';   % ligne ou colonne
    [~, registre.crcErrFlag] = decodeCRC(bitPacketCRC);

    message = bitPacketCRC(1:88);

    %Downlink Format
    DF = bin2dec_custom(message(1:5));
    registre.format = DF;

    % Capacité
    % CA = bin2dec_custom(message(6:8));

    % Adresse ICAO (6 chiffres hexadécimaux, ex. '3420CA')
    adresse_bits = message(9:32);
    registre.adresse = dec2hex(bin2dec_custom(adresse_bits), 6);

    % seules les trames ADS-B (DF = 17) sont décodées
    if DF ~= 17
        return;
    end

    % Données ADS-B
    data = message(33:88);
    
    % Format Type Code
    FTC = bin2dec_custom(data(1:5));
    registre.type = FTC;
    
    % Messages d'identification: FTC = 1 à 4
    if FTC >= 1 && FTC <= 4
        registre.planeName = decodeCallsign(data);

    % Messages de position en vol: FTC = 9 à 18
    elseif FTC >= 9 && FTC <= 18
        registre.altitude = decodeAltitude(data(9:20));

        % data(21) : indicateur de temps UTC, non utilisé
        registre.cprf = data(22);

        % CPR encoded lat/lon
        lat = data(23:39);
        lon = data(40:56);
        LAT = bin2dec_custom(lat);
        LON = bin2dec_custom(lon);

        [registre.longitude, registre.latitude] = cpr2LatLon(LAT, LON, registre.cprf, refLat, refLon);
    end
end

%% Fonction pour décoder l'altitude
function altitude = decodeAltitude(altitude_bits)
    %bits utiles "Le 8eme bits de ba étant inutile dans notre cas, il ne doit pas être considéré"
    ra = [altitude_bits(1:7), altitude_bits(9:12)];
    ra_val = bin2dec_custom(ra);
    altitude = 25 * ra_val - 1000;  % en pieds
end

function callsign = decodeCallsign(data)
    % 8 caractères, espaces compris (comme la référence)
    callsign = blanks(8);
    for char_num = 1:8
        start_bit = 9 + (char_num - 1) * 6;
        end_bit = start_bit + 5;
        char_bits = data(start_bit:end_bit);

        char_val = bin2dec_custom(char_bits);
        callsign(char_num) = value_to_char(char_val);
    end
end

function character = value_to_char(value)
    if value >= 1 && value <= 26
        character = char(64 + value);  % A-Z
    elseif value >= 48 && value <= 57
        character = char(value);  % 0-9
    elseif value == 32
        character = ' ';
    else
        character = '-';  % code non défini
    end
end

function decimal = bin2dec_custom(bin)
    % convert binary array to decimal
    n = length(bin);
    decimal = 0;
    for i = 1:n
        decimal = decimal + bin(i) * 2^(n-i);
    end
end
