function res = verif_modulatePPM()
% modulatePPM contre modulatePPM_ (symboles 0, 1 et -1, ligne et colonne)
% et préambule : modulatePPM([1 1 -1 0 0 -1 -1 -1]) doit redonner
% get_preamble_ et notre preambule(Fse).

rng(33);
nb_cas = 0;
for Fse = [4 20]
    for k = 1:50
        s = randi([-1 1], 1, 120);
        m = modulatePPM(s, Fse);
        m_col = modulatePPM(s(:), Fse);
        m_ref = avec_reference(@() modulatePPM_(s, Fse));
        assert(isrow(m) && isequal(m, m_col), 'modulatePPM : forme de sortie');
        assert(isequal(m, m_ref), 'modulatePPM différent de modulatePPM_ (Fse = %d)', Fse);
        nb_cas = nb_cas + 1;
    end

    p = modulatePPM([1 1 -1 0 0 -1 -1 -1], Fse);
    p_ref = avec_reference(@() get_preamble_(Fse));
    assert(isequal(p, p_ref), 'préambule différent de get_preamble_ (Fse = %d)', Fse);
    assert(isequal(p, preambule(Fse)), 'préambule différent de preambule(%d)', Fse);
    assert(isequal(get_preamble(Fse), p_ref), 'get_preamble différent de get_preamble_ (Fse = %d)', Fse);
end

res.chiffres = sprintf('%d séquences identiques à modulatePPM_ ; get_preamble = get_preamble_ = preambule (Fse = 4 et 20)', nb_cas);
fprintf('  modulatePPM : %s\n', res.chiffres);
end
