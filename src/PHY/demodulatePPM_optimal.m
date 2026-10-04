function bits = demodulatePPM_optimal(packet, Fse)
    p1 = [ones(1,Fse/2), zeros(1,Fse/2)];
    bits = zeros(1, length(packet)/Fse);
    v0 = sum(p1.^2);
    
    for k = 1:length(packet)/Fse
        packet_k = packet((k-1)*Fse + (1:Fse));
        middle_point = Fse/2;
        r0 = sum(packet_k(1:middle_point));
        r1 = sum(packet_k(middle_point+1:end));
        d0 = (r0 - 0).^2 + (r1 - v0).^2;
        d1 = (r0 - v0).^2 + (r1 - 0).^2;
    
        bits(k) = (d1 < d0);
    end
end

