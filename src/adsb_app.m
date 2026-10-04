function [listOfPlanes, durees] = adsb_app(source, nb_buffers)
%% ADSB Application
% Adapté du squelette d'application fourni avec le sujet TS229
% (TS229 course repository) : ajout du rejeu des enregistrements, du
% numéro de buffer, de la position des trames et de la mesure des durées.
% adsb_app ou adsb_app('radio') : radio logicielle de l'école (get_buffer),
%   boucle sans fin ;
% adsb_app('rejeu') : rejoue les 9 buffers enregistrés (data/buffers.mat),
%   un toutes les 0,5 s à la place de get_buffer, puis s'arrête ;
% adsb_app('rejeu', k) : s'arrête après les k premiers buffers (carte à
%   une étape intermédiaire).
% Rend la liste des avions et, pour chaque buffer, la durée du traitement
% (décodage, liste des avions, carte), qui doit rester sous 0,5 s pour
% suivre la radio en direct.
%% Initialisation
if nargin < 1
    source = 'radio';
end
if nargin < 2
    nb_buffers = Inf;
end
close all

dossier = fileparts(mfilename('fullpath'));
% en fin de chemin : ne pas passer devant des dossiers déjà placés en tête,
% comme les pièges des fonctions .p des tests (sans_fonctions_p)
addpath(fullfile(dossier, 'Client'), fullfile(dossier, 'General'), ...
        fullfile(dossier, 'MAC'), fullfile(dossier, 'PHY'), '-end');
%% Constants definition
DISPLAY_MASK = '| %12.12s | %10.10s | %6.6s | %3.3s | %6.6s | %3.3s | %8.8s | %11.11s | %4.4s | %12.12s | %12.12s | %3.3s |\n'; % Format pour l'affichage
CHAR_LINE = '+--------------+------------+--------+-----+--------+-----+----------+-------------+------+--------------+--------------+-----+\n'; % Lignes

SERVER_ADDRESS = 'rpprojets.enseirb-matmeca.fr';

% Coordonnees de reference (endroit de l'antenne)
REF_LON = -0.606629; % Longitude de l'ENSEIRB-Matmeca
REF_LAT = 44.806884; % Latitude de l'ENSEIRB-Matmeca

affiche_carte(REF_LON, REF_LAT);

%% Couche Physique
Fe = 4e6; % Frequence d'echantillonnage (imposee par le serveur)
Rb = 1e6;% Debit binaire (=debit symbole)
Fse = floor(Fe/Rb); % Nombre d'echantillons par symboles
seuil_detection = 0.75; % Seuil pour la detection des trames (entre 0 et 1)

%% Affichage d'une entete en console
fprintf(CHAR_LINE)
fprintf(DISPLAY_MASK,'  n (buffer)  ',' t (in s) ','Corr.', 'DF', '  AA  ','FTC','   CS   ','ALT (in ft)','CPRF','LON (in deg)','LAT (in deg)','CRC')
fprintf(CHAR_LINE)

%% Boucle principale
listOfPlanes = [];
durees = [];
n = 1;
while true
    cprintf('blue',CHAR_LINE)
    switch source
        case 'radio'
            cplxBuffer = get_buffer(SERVER_ADDRESS);
        case 'rejeu'
            cplxBuffer = [];
            if n <= nb_buffers
                cplxBuffer = get_buffer_rejeu(n);
            end
            if isempty(cplxBuffer)
                break;
            end
        otherwise
            error('adsb_app:source', 'source inconnue : %s (radio ou rejeu)', source);
    end
    debut = tic;

    [liste_new_registre, liste_corrVal, liste_pos] = process_buffer(cplxBuffer, REF_LON, REF_LAT, seuil_detection, Fse);
    % liste_corrVal représente les valeurs de corrélations au format vecteur pour affichage dans la console
    % liste_new_registre représente l'ensemble des registres détectés dans cplxBuffer au format cell
    % liste_pos : début de chaque trame dans le buffer (en échantillons)
    listOfPlanes = update_liste_avion(listOfPlanes, liste_new_registre, DISPLAY_MASK, Fe, n, liste_corrVal, liste_pos);

    for plane_ = listOfPlanes
        plot(plane_);
    end
    ecarter_etiquettes(listOfPlanes);
    drawnow;
    durees(n) = toc(debut); %#ok<AGROW>
    n = n + 1;
end
end
