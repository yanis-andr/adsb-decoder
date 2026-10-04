function res = test_task6_mac()
% Tâche 6 ST3 : décoder adsb_msgs.mat avec bit2registre et tracer la
% trajectoire de l'avion. Attendu : un seul avion (3420CA, IBE3405),
% 25 positions en vol et 2 identifications, CRC bons.

data = load(fullfile(dossier_projet(), 'data', 'adsb_msgs.mat'), 'adsb_msgs');
adsb_msgs = data.adsb_msgs;

% Position de référence : ENSEIRB-Matmeca (antenne)
refLat = 44.806884;
refLon = -0.606629;

numFrames = size(adsb_msgs, 2);
registres = cell(numFrames, 1);

for i = 1:numFrames
    frame = adsb_msgs(:, i)';
    registres{i} = bit2registre(frame, refLon, refLat);
end

% Extract info
latitudes = [];
longitudes = [];
altitudes = [];
callsign = '';
adresses = {};
nb_crc_faux = 0;

for i = 1:numFrames
    nb_crc_faux = nb_crc_faux + registres{i}.crcErrFlag;
    if registres{i}.crcErrFlag == 0
        adresses{end+1} = registres{i}.adresse; %#ok<AGROW>
        if ~isempty(registres{i}.planeName)
            callsign = strtrim(registres{i}.planeName);
        end
        if ~isempty(registres{i}.latitude) && ~isempty(registres{i}.longitude)
            latitudes = [latitudes, registres{i}.latitude];
            longitudes = [longitudes, registres{i}.longitude];
            altitudes = [altitudes, registres{i}.altitude];
        end
    end
end

assert(nb_crc_faux == 0, '%d trames à CRC faux', nb_crc_faux);
assert(numel(unique(adresses)) == 1 && strcmp(adresses{1}, '3420CA'), 'un seul avion 3420CA attendu');
assert(strcmp(callsign, 'IBE3405'), 'indicatif %s au lieu de IBE3405', callsign);
assert(numel(latitudes) == 25, '%d positions au lieu de 25', numel(latitudes));

% Trajectoire sur la carte (affiche_carte dessine dans la figure 1)
affiche_carte(refLon, refLat);
fig = gcf;
hold on;
plot(longitudes, latitudes, 'b-', 'LineWidth', 2);
plot(longitudes, latitudes, 'bo', 'MarkerSize', 5);
plot(longitudes(1), latitudes(1), 'go', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
plot(longitudes(end), latitudes(end), 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
text(longitudes(end) + 0.03, latitudes(end) - 0.05, callsign, ...
     'FontSize', 12, 'FontWeight', 'bold', 'Color', 'r', ...
     'BackgroundColor', 'w', 'EdgeColor', 'k');
% la carte s'arrête à 45,17° N : on élargit pour voir le début de la trajectoire
xlim([-1.3581, max(0.7128, max(longitudes) + 0.1)]);
ylim([44.4542, max(45.1683, max(latitudes) + 0.1)]);
title(sprintf('Trajectoire de %s (0x3420CA), %d positions, %d à %d ft', ...
    callsign, numel(latitudes), min(altitudes), max(altitudes)));
h = findobj(gca, 'Type', 'line');
legend(h([4 3 2 1]), 'trajectoire', 'positions', 'début', 'fin', 'Location', 'southwest');
sauver_figure(fig, 'tache6_trajectoire');

res.chiffres = sprintf('%d trames, CRC bons, avion 3420CA %s, %d positions de (%.2f ; %.2f) à (%.2f ; %.2f), %d à %d ft', ...
    numFrames, callsign, numel(latitudes), latitudes(1), longitudes(1), latitudes(end), longitudes(end), ...
    min(altitudes), max(altitudes));
fprintf('  Tâche 6 ST3 : %s\n', res.chiffres);
end
