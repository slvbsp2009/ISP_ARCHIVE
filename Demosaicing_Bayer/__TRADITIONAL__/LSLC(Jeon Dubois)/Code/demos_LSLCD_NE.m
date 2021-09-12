% Demosaicking of Noisy Bayer-Sampled Color Images with Least-Squares
% Luma-Chroma Demultiplexing and Noise Level Estimation
%
% IEEE Trans. Image Processing (submitted)
% This software is for provided for non-commercial and research purposes only
% Copyright Eric Dubois (edubois@site.uottawa.ca), University of Ottawa 2011 
%  
%       [RGB] = demos_LSLCD_NE(CFA, fpkg, sigma, method)
%       CFA(:,:)   input Bayer CFA mosaicked image, double according to the
%       pattern       G R
%                     B G
%       fpkg       path of the filter package that contains the follwing
%                  filter: h1, h2a, h2b, hL, hG1, hG2
%       sigma      added noise (sigma_A) or estimated noise (sigma_E) 
%       method     1: h_LN, 2: BM3D 
%       RGB(:,:,3) output RGB image, double
%       BM3D can be downloaded: http://www.cs.tut.fi/~foi/GCF-BM3D/

function [RGB] = demos_LSLCD_NE(CFA, fpkg, sigma, method)

% Load the filter package
load(fpkg);

% Use the filters to demosaic the CFA image
S = size(CFA); N1 = S(1); N2 = S(2);
yc = 0:N1-1; xc = 0:N2-1;
[XC,YC] = meshgrid(xc,yc);

% Filter the input image with the two Gaussian filters to get energy terms
eX = imfilter(CFA,hG1,'replicate','same').^2;
eY = imfilter(CFA,hG2,'replicate','same').^2;
% Average energy with moving average filter
NMA=5; h_MA = ones(NMA,NMA)/(NMA^2);
eX = imfilter(eX,h_MA,'replicate','same');
eY = imfilter(eY,h_MA,'replicate','same');
% Compute weighting coefficients
w = eY./(eX+eY);

% Extract chrominance in corners using h1
C1mhat = imfilter(CFA,h1,'replicate','same');
% Extract chrominance on sides at f_y = 0
C2mahat = imfilter(CFA,h2a,'replicate','same');
% Extract chrominance on sides at f_x = 0
C2mbhat = imfilter(CFA,h2b,'replicate','same');

% Estimate the C2 component
C2hat = (w.*C2mahat.*(-1).^(XC) - (1-w).*C2mbhat.*(-1).^(YC));
% Estimate the C1 component
C1hat = C1mhat.*(-1).^(XC+YC);
% Estimate the Luma component
Lhatn = CFA - C1mhat - C2hat.*((-1).^XC - (-1).^YC);

if method == 1
    if sigma<=0
        Lhat = Lhatn;
    else                
        Lhat = imfilter(Lhatn,hL,'replicate','same');
    end
elseif method == 2
    if sigma<=0
        Lhat = Lhatn;
    else                
        [dummy,Lhat]=BM3D(1,Lhatn,sigma);
    end
else
    display('error');
end

% Reconstruct the RGB image
RGB(:,:,1) = Lhat - C1hat - 2*C2hat;
RGB(:,:,2) = Lhat + C1hat;
RGB(:,:,3) = Lhat - C1hat + 2*C2hat;