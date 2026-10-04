function [res] = cprMod(a, b)
    res = a - b * floor(a / b);
end
