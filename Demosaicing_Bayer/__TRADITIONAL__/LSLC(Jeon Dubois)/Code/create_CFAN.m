% Demosaicking of Noisy Bayer-Sampled Color Images with Least-Squares
% Luma-Chroma Demultiplexing and Noise Level Estimation
% 
% Perform creating CFA 
%
% IEEE Trans. Image Processing (submitted)
% This software is for provided for non-commercial and research purposes only
% Copyright Eric Dubois (edubois@site.uottawa.ca), University of Ottawa
% 2011
%
%      [CFA] = create_CFA(RGB,sigma)
%      RGB(:,:,3)   input RGB image
%      CFA(:,:)     output Bayer CFA mosaicked image
%
%      Upper left pixel is green, pixel to right of it is red, pixel below it is
%      blue
%
%      G R
%      B G
%
function [CFAN] = create_CFAN(RGB,sigma)

S = size(RGB); N1 = S(1); N2 = S(2);
CFAN = zeros(N1,N2);

alphaR = 1.8523;
alphaG = 0.6891;
alphaB = 1.0000;

randn('state',0); noi=randn(N1,N2); noi=noi/255;
sigmaR = sqrt(alphaR)*sigma; sigmaG = sqrt(alphaG)*sigma; sigmaB = sqrt(alphaB)*sigma;         
tetaR = sigmaR*noi; tetaG = sigmaG*noi; tetaB = sigmaB*noi; 
teta = zeros(N1,N2,3); teta(:,:,1) = tetaR; teta(:,:,2) = tetaG; teta(:,:,3) = tetaB;
RGBn = RGB + teta;

CFAN(1:2:N1,2:2:N2) = RGBn(1:2:N1,2:2:N2,1); %red
CFAN(1:2:N1,1:2:N2) = RGBn(1:2:N1,1:2:N2,2); %green
CFAN(2:2:N1,2:2:N2) = RGBn(2:2:N1,2:2:N2,2); %green
CFAN(2:2:N1,1:2:N2) = RGBn(2:2:N1,1:2:N2,3); %blue       
        
