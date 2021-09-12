function [PSNR] = psnr(X,Xest)

% Computes PSNR error criterion

if max(X(:)>2), maxl2=255*255; else maxl2=1; end;

rmse_noisy=mean((Xest(:)-X(:)).^2);
psnr_noisy=10*log10(maxl2/rmse_noisy);
PSNR = psnr_noisy;