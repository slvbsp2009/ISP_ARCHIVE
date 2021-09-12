%--------------------------------------------------------------------------
%
%  Yue M. Lu
%  Ecole Polytechnique Federale de Lausanne (EPFL)
%
%--------------------------------------------------------------------------
%
%  compare_imgs.m
%
%  First created: 06-08-2008
%  Last modified: 06-11-2009
%
%--------------------------------------------------------------------------

function [psnr_arr, mse_arr] = compare_imgs(x, y, skip)

%  Calculate the PSNR and MSE between two color images
%
%  INPUT
%
%    x, y: two color images
%
%    skip: the number of border pixels to exclude in computing the PSNR and
%    MSE.
%
%  OUTPUT
%
%    psnr_arr: a 1-by-4 array [PSNR_Red, PSNR_Green, PSNR_Blue, PSNR_total]
%    mse_arr: a 1-by-4 array [MSE_Red, MSE_Green, MSE_Blue, MSE_total]

x = double(x(skip+1:end-skip, skip+1:end-skip, :));
y = double(y(skip+1:end-skip, skip+1:end-skip, :));

diff = x - y;

mse_arr = zeros(1, 4);

% calcuate the MSE for each channel            
mse_arr(1) = mean2(diff(:,:,1).^2);
mse_arr(2) = mean2(diff(:,:,2).^2);
mse_arr(3) = mean2(diff(:,:,3).^2);
mse_arr(4) = mean(diff(:).^2);

% calculate the PSNR
psnr_arr = 10 * log10(255^2 ./ mse_arr);
        
