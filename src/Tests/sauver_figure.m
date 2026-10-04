function chemin = sauver_figure(fig, nom)
% Sauve la figure en PNG dans docs/figures/<nom>.png.
    dossier = fullfile(dossier_projet(), 'docs', 'figures');
    if ~exist(dossier, 'dir')
        mkdir(dossier);
    end
    chemin = fullfile(dossier, [nom '.png']);
    exportgraphics(fig, chemin, 'Resolution', 130);
end
