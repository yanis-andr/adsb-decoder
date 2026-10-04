function buffer = get_buffer_rejeu(n)
% Remplace get_buffer quand la radio de l'école n'est pas joignable :
% rend le buffer n de data/buffers.mat, au même format que get_buffer
% (vecteur ligne complexe). Un buffer n'est rendu que lorsque la durée du
% précédent (0,5 s à 4 MHz) est écoulée depuis qu'il a été rendu : c'est la
% cadence d'un flux continu. Les enregistrements étaient en fait espacés
% d'environ 10 à 16 s (estimation par les vitesses des avions,
% README.md) : le rejeu est accéléré d'environ 25 fois.
% Rend [] après le dernier buffer.
    persistent buffers duree dernier
    if isempty(buffers)
        racine = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        S = load(fullfile(racine, 'data', 'buffers.mat'), 'buffers', 'Rs');
        buffers = S.buffers;
        duree = size(buffers, 1) / S.Rs;
    end
    if n == 1
        dernier = [];   % nouveau rejeu
    end
    if n > size(buffers, 2)
        buffer = [];
        return;
    end

    if ~isempty(dernier)
        attente = duree - toc(dernier);
        if attente > 0
            pause(attente);
        end
    end
    dernier = tic;
    buffer = buffers(:, n).';
end
