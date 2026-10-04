function [delta_t_hat,rho] = shift_estimation(yl,sp,retard_max)
    % retard cherché entre 0 et retard_max échantillons (par défaut :
    % tout le signal). Chercher au-delà du retard possible fait accrocher
    % des impulsions de données qui ressemblent au préambule.
    yl = yl(:).';
    sp = sp(:).';
    if nargin < 3
        retard_max = length(yl) - length(sp);
    end
    max_search_samples = min(retard_max, length(yl) - length(sp)) + 1;
    search_range = 1:max_search_samples;
    
    rho = zeros(1, max_search_samples);
    E_sp = sum(abs(sp).^2);
    
    for idx = 1:length(search_range)
        i = search_range(idx);

        if i + length(sp) - 1 > length(yl)
            break;
        end
        
        yl_seg = yl(i:i+length(sp)-1);
        
        % correlation
        numerator = sum(yl_seg .* conj(sp));
        
        % ne depend pas de la phase
        E_yl = sum(abs(yl_seg).^2);
        denom = sqrt(E_sp * E_yl);
        
        if denom > 0
            rho(idx) = numerator / denom;
        else
            rho(idx) = 0;
        end
    end
    
    [~, peak_idx] = max(abs(rho));
    delta_t_hat = search_range(peak_idx) - 1;
end