function [Par] = Parsetting( Par )
%% initialization
Par.pixel_weights = zeros(Par.size_patch);
mid = ceil(Par.size_patch/2);
sig = floor(Par.size_patch/2)/Par.weightsSig;
for i=1:Par.size_patch
    for j=1:Par.size_patch
        d = sqrt((i-mid)^2 + (j-mid)^2); 
        Par.pixel_weights(i,j) = exp((-d^2)/(2*(sig^2))) / (sig*sqrt(2*pi));
    end
end
end

