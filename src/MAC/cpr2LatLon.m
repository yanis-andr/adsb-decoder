function [lon, lat] = cpr2LatLon(regLAT, regLON, CPRF, refLat, refLon)
    NZ = 15;  % zones de latitude
    Nb = 17;  % bits pour la latitude/longitude
    
    LAT = regLAT;
    LON = regLON;
    i = CPRF;
    
    % Latitude decoding
    Dlati = 360 / (4 * NZ - i);
    j = floor(refLat / Dlati) + floor(0.5 + cprMod(refLat, Dlati) / Dlati - LAT / (2^Nb));
    lat = Dlati * (j + LAT / (2^Nb));

    % Longitude decoding
    NL_lat = cprNL(lat);
    
    if (NL_lat - i) > 0
        Dloni = 360 / (NL_lat - i);
    else
        Dloni = 360;
    end
    
    m = floor(refLon / Dloni) + floor(0.5 + cprMod(refLon, Dloni) / Dloni - LON / (2^Nb));
    lon = Dloni * (m + LON / (2^Nb));
    
    % correction de wraparound
    if lat >= 270
        lat = lat - 360;
    end
    
    if lon >= 180
        lon = lon - 360;
    end
    
end
