%--------------------------------------------------------------------------
%
%  Yue M. Lu
%  Ecole Polytechnique Federale de Lausanne (EPFL)
%
%--------------------------------------------------------------------------
%
%  plot_convergence.m
%
%  First created: 01-14-2009
%  Last modified: 06-09-2009
%
%--------------------------------------------------------------------------

% Demonstrating the convergence property of the AP algorithm with three
% different initial estimations: bilinear interpolation, all zero, and
% random. The final convergence result of the AP algorithm does not depend
% on the intial estimations.

p = mfilename('fullpath');
fname = [p(1:length(p)-23) 'Images/'];
img_idx = 19; % light house

niter = 40;
IsPrint = 0;

% Load the image
if img_idx < 10
    x = imread([fname '0' num2str(img_idx) '.tif']);
else
    x = imread([fname num2str(img_idx) '.tif']);
end
   
x = double(x);
x_bayer = cfa_Bayer(x);

% Obtain the convergence value by using bilinear interpolation as the
% initial estimate
[r_conv, r0_bl, mse_list] = d_pocs_rec(x_bayer, niter + 20);

% Compute the mse at each iteration with different initial estimates

% 1. Bilinear interpolation
[r, r0, mse_bilinear] = d_pocs_rec(x_bayer, niter, r0_bl, r_conv);

% 2. All zero
[r, r0, mse_zero] = d_pocs_rec(x_bayer, niter, zeros(size(x_bayer)), r_conv);

% 3. Random
[r, r0, mse_rand] = d_pocs_rec(x_bayer, niter, 255 * rand(size(x_bayer)), r_conv);

h = figure
semilogy([0 : niter], mse_zero, 'r--', 'LineWidth', 2.5);

hold on;
%plot([0 : niter], log10(mse_zero(1) * 0.75.^([0:niter]*2)));


semilogy([0 : niter], mse_rand, 'b-.', 'LineWidth', 2.5);
%plot([0 : niter], log10(mse_rand(1) * 0.75.^([0:niter]*2)));

semilogy([0 : niter], mse_bilinear, 'k', 'LineWidth', 2.5);
%plot([0 : niter], log10(mse_bilinear(1) * 0.75.^([0:niter]*2)));
%axis([0 35 -1 5]);
xlabel('iteration number');
ylabel('MSE');
grid on
text(11, 10^(-3), 'bilinear')
text(25, 10^(-1), 'zero') 
text(16, 10^(-2), 'random')

if IsPrint
    set(0,'defaulttextinterpreter','none')
    laprint(h, ['convergence' ], 'color', 'on', 'width', 18);
end

