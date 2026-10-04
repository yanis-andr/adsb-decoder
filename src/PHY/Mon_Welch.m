function [y, f] = Mon_Welch(x, Nfft, Fe)
    % Welch sans recouvrement ni fenêtre : moyenne des |FFT|^2 sur des
    % blocs de Nfft points. y en puissance par Hz (somme(y)*Fe/Nfft =
    % puissance de x), fréquences centrées de -Fe/2 à Fe/2 - Fe/Nfft.

    P = floor(length(x)/Nfft);
    decoup = reshape(x(1:P*Nfft), Nfft, P);
    x_fft = fftshift(fft(decoup, Nfft), 1);
    module = abs(x_fft).^2/(Fe*Nfft);
    y = mean(module, 2);
    f = (-Nfft/2:Nfft/2-1)*(Fe/Nfft);
end
