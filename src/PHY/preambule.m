function [sp] = preambule(Fse)
    half_period = Fse/2;
    

    pattern = [1 0 1 0 0 0 0 1 0 1 0 0 0 0 0 0];
    sp = [];
    for i = 1:length(pattern)
        if pattern(i) == 1
            sp = [sp, ones(1, half_period)];
        else
            sp = [sp, zeros(1, half_period)];
        end
    end
end