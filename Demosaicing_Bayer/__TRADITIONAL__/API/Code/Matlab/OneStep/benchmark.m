%--------------------------------------------------------------------------
%
%  Yue M. Lu
%  Ecole Polytechnique Federale de Lausanne (EPFL)
%
%--------------------------------------------------------------------------
%
%  benchmark.m
%
%  First created: 06-08-2008
%  Last modified: 06-11-2009
%
%--------------------------------------------------------------------------

%  Compare the original AP algorithm and the proposed one-step
%  implementation


%  Note: to reproduce the partial convergence results, set IsConvergence =
%  0 and niter = 6; for the full convergence results, set IsConvergence = 1
%  and niter = 20.

% 0 for partial convergence, 1 for full convergence
IsConvergence = 0; 

% number of iterations used by the AP algorithm
niter = 6; 

% Truncate all polyphase filters to the size of K-by-K
K = 6;  

% 0: use the original nonseparable filters; 1: use separable approximations
% (i.e. rank-one approximations); 2: use rank-two approximations; and so on
approx_rank = 1; 

% exclude certain number of pixels along each side of the border in
% calculating the PSNR
skip = 10;

% The directory containing the test images
p = mfilename('fullpath');
fname = [p(1:length(p)-16) 'Images/'];

% The set of images used in the test
img_set = 1 : 24;
%img_set = 1;

% load the pre-computed filters
if IsConvergence
    [flts_r, flts_b] = simplify_filters(20, K);
else
    [flts_r, flts_b] = simplify_filters(niter, K);
end

if exist('DemoPOCS', 'dir') ~= 7
    error('The directory DemoPOCS should be on the Matlab search path.');
end

N = length(img_set);
psnr_array_ap = zeros(N, 4);
t_array_ap = zeros(N, 1);

psnr_array_onestep = zeros(N, 4);
t_array_onestep = zeros(N, 1);

h = waitbar(0, 'Please wait ...');
for n = 1 : N
    img_idx = img_set(n);
    if img_idx < 10
        x = imread([fname '0' num2str(img_idx) '.tif']);
    else
        x = imread([fname num2str(img_idx) '.tif']);
    end
    
    x = double(x);
    x_bayer = cfa_Bayer(x);
     
    %----------------------------------------------------------------------
    % AP demosaicking: the original iterative implementation
    %----------------------------------------------------------------------
    
    [out, t] = d_pocs2(x_bayer, niter);

    t_array_ap(n) = t;
    
    [psnr_arr, mse_arr] = compare_imgs(x, out, skip);
    psnr_array_ap(n, :) = psnr_arr;
   
    %----------------------------------------------------------------------
    % AP demosaicking: the new one-step implementation
    %----------------------------------------------------------------------
    
    if IsConvergence
        [xh, t] = onestep_demosaicking_conv(x_bayer, flts_r, flts_b, approx_rank);
    else
        [xh, t] = onestep_demosaicking_part(x_bayer, flts_r, flts_b, approx_rank);
    end
    
    t_array_onestep(n) = t;
    
    [psnr_arr, mse_arr] = compare_imgs(x, xh, skip);
    psnr_array_onestep(n, :) = psnr_arr;
    
    waitbar(n/N, h);
end
close(h)

% show the results
format short
disp(' ');
disp(' ');
disp('Average PSNR (first row: iterative; second row: one-step)');
disp('   Red       Green     Blue      CPSNR');
disp(mean(psnr_array_ap));
disp(mean(psnr_array_onestep));

disp(['Average time (iterative) = ' num2str(mean(t_array_ap)) ' seconds']);
disp(['Average time (one-step) = ' num2str(mean(t_array_onestep)) ' seconds']);
disp(['Speedup Factor = ' num2str(mean(t_array_ap)/mean(t_array_onestep))]);