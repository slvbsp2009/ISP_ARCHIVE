%--------------------------------------------------------------------------
%
%  Yue M. Lu
%  Ecole Polytechnique Federale de Lausanne (EPFL)
%
%--------------------------------------------------------------------------
%
%  onestep_demosaicking_part.m
%
%  First created: 01-12-2009
%  Last modified: 06-09-2009
%
%--------------------------------------------------------------------------

function [xh, t] = onestep_demosaicking_part(x_bayer, flts_r, flts_b, approx_rank)

%  One-Step implementation of the AP algorithm (mode: partial convergence)
%  
%  INPUT
%    x_bayer: the CFA measurement
%    
%    flts_r: the polyphase filters for the red channel
%
%    flts_b: the polyphase filters for the blue channel
%
%    approx_rank: 
%      0 (no low-rank approximation, using the original 2-D nonseparable filter)
%      1 (replace the filters with their optimal separable, i.e., rank-1, approximations)
%      2 (replace the filers with their optimal rank-2 approximations)
%      3 ... And so on
%
%  OUTPUT
%    xh: the reconstructed color image
%
%    t: the total running time (in seconds)


% Step 1: initial estimation of the green channel

tic;

x_bayer = double(x_bayer);

sz = size(x_bayer);

% edge-sensitive interpolation of the green channel
g = esi_g(x_bayer);

% filters used in subband decomposition 
L = conv([1 2 1]/4, [-1 2 6 2 -1]/8);

% update the green channel
r01 = x_bayer(1:2:end,2:2:end); 
g01 = r01 + conv2(L, L, g(1:2:end,2:2:end) - r01, 'same');
g01(g01 < 0) = 0;
g01(g01 > 255) = 255;

b10 = x_bayer(2:2:end,1:2:end);
g10 = b10 + conv2(L, L, g(2:2:end,1:2:end) - b10, 'same');
g10(g10 < 0) = 0;
g10(g10 > 255) = 255;

g(1:2:end, 2:2:end) = g01;
g(2:2:end, 1:2:end) = g10;


% Step 2: one-step refinement of the red and blue channels

g00 = g(1:2:end, 1:2:end);
g11 = g(2:2:end, 2:2:end);

% the red channel
ch01 = r01 - g01;
r = zeros(sz);

% Calculate the partial convergence result
ch00 = conv2(1, [0 0.5 0.5], r01, 'same') - g00;
ch10 = conv2([0.5 0.5], [0 0.5 0.5], r01, 'same') - g10;
ch11 = conv2([0.5 0.5], 1, r01, 'same') - g11;

if approx_rank == 0
    % direct implementation using 2-D filters
    r(1:2:end,1:2:end) = conv2(ch00, flts_r{1,1}{end}, 'same') ...
            + conv2(ch01, flts_r{1,2}{end}, 'same') ...
            + conv2(ch10, flts_r{1,3}{end}, 'same') ...
            + conv2(ch11, flts_r{1,4}{end}, 'same') + g00;
    r(2:2:end,1:2:end) = conv2(ch00, flts_r{2,1}{end}, 'same') ...
            + conv2(ch01, flts_r{2,2}{end}, 'same') ...
            + conv2(ch10, flts_r{2,3}{end}, 'same') ...
            + conv2(ch11, flts_r{2,4}{end}, 'same') + g10;
    r(2:2:end,2:2:end) = conv2(ch00, flts_r{3,1}{end}, 'same') ...
            + conv2(ch01, flts_r{3,2}{end}, 'same') ...
            + conv2(ch10, flts_r{3,3}{end}, 'same') ...
            + conv2(ch11, flts_r{3,4}{end}, 'same') + g11;
else
    % using separable approximations
    r(1:2:end,1:2:end) = conv2(flts_r{1,1}{1}, flts_r{1,1}{2}, ch00, 'same') ...
            + conv2(flts_r{1,2}{1}, flts_r{1,2}{2}, ch01, 'same') ...
            + conv2(flts_r{1,3}{1}, flts_r{1,3}{2}, ch10, 'same') ...
            + conv2(flts_r{1,4}{1}, flts_r{1,4}{2}, ch11, 'same') + g00;
    
    r(2:2:end,1:2:end) = conv2(flts_r{2,1}{1}, flts_r{2,1}{2}, ch00, 'same') ...
            + conv2(flts_r{2,2}{1}, flts_r{2,2}{2}, ch01, 'same') ...
            + conv2(flts_r{2,3}{1}, flts_r{2,3}{2}, ch10, 'same') ...
            + conv2(flts_r{2,4}{1}, flts_r{2,4}{2}, ch11, 'same') + g10;
    
    r(2:2:end,2:2:end) = conv2(flts_r{3,1}{1}, flts_r{3,1}{2}, ch00, 'same') ...
            + conv2(flts_r{3,2}{1}, flts_r{3,2}{2}, ch01, 'same') ...
            + conv2(flts_r{3,3}{1}, flts_r{3,3}{2}, ch10, 'same') ...
            + conv2(flts_r{3,4}{1}, flts_r{3,4}{2}, ch11, 'same') + g11;
   
    % if we need to have higher-order approximations, for improved
    % precision but at the price of more computation    
    for n = 2 : approx_rank
        r(1:2:end,1:2:end) = conv2(flts_r{1,1}{2*n-1}, flts_r{1,1}{2*n}, ch00, 'same') ...
            + conv2(flts_r{1,2}{2*n-1}, flts_r{1,2}{2*n}, ch01, 'same') ...
            + conv2(flts_r{1,3}{2*n-1}, flts_r{1,3}{2*n}, ch10, 'same') ...
            + conv2(flts_r{1,4}{2*n-1}, flts_r{1,4}{2*n}, ch11, 'same') + r(1:2:end,1:2:end);
        r(2:2:end,1:2:end) = conv2(flts_r{2,1}{2*n-1}, flts_r{2,1}{2*n}, ch00, 'same') ...
            + conv2(flts_r{2,2}{2*n-1}, flts_r{2,2}{2*n}, ch01, 'same') ...
            + conv2(flts_r{2,3}{2*n-1}, flts_r{2,3}{2*n}, ch10, 'same') ...
            + conv2(flts_r{2,4}{2*n-1}, flts_r{2,4}{2*n}, ch11, 'same') + r(2:2:end,1:2:end);
    
        r(2:2:end,2:2:end) = conv2(flts_r{3,1}{2*n-1}, flts_r{3,1}{2*n}, ch00, 'same') ...
            + conv2(flts_r{3,2}{2*n-1}, flts_r{3,2}{2*n}, ch01, 'same') ...
            + conv2(flts_r{3,3}{2*n-1}, flts_r{3,3}{2*n}, ch10, 'same') ...
            + conv2(flts_r{3,4}{2*n-1}, flts_r{3,4}{2*n}, ch11, 'same') + r(2:2:end,2:2:end);
    end
end

r(1:2:end,2:2:end) = r01;

r(r < 0) = 0;
r(r > 255) = 255;


% the blue channel
ch10 = b10 - g10;
b = zeros(sz);

% Calculate the partial convergence result
ch00 = conv2([0 0.5 0.5], 1, b10, 'same') - g00;
ch01 = conv2([0 0.5 0.5], [0.5 0.5], b10, 'same') - g01;
ch11 = conv2(1, [0.5 0.5], b10, 'same') - g11;

if approx_rank == 0
    % direct implementation using 2-D filters
    b(1:2:end,1:2:end) = conv2(ch00, flts_b{1,1}{end}, 'same') ...
        + conv2(ch01, flts_b{1,2}{end}, 'same') ...
        + conv2(ch10, flts_b{1,3}{end}, 'same') ...
        + conv2(ch11, flts_b{1,4}{end}, 'same') + g00;
    
    b(1:2:end,2:2:end) = conv2(ch00, flts_b{2,1}{end}, 'same') ...
        + conv2(ch01, flts_b{2,2}{end}, 'same') ...
        + conv2(ch10, flts_b{2,3}{end}, 'same') ...
        + conv2(ch11, flts_b{2,4}{end}, 'same') + g01;
    
    b(2:2:end,2:2:end) = conv2(ch00, flts_b{3,1}{end}, 'same') ...
        + conv2(ch01, flts_b{3,2}{end}, 'same') ...
        + conv2(ch10, flts_b{3,3}{end}, 'same') ...
        + conv2(ch11, flts_b{3,4}{end}, 'same') + g11;
    
else
    % using separable approximations
    b(1:2:end,1:2:end) = conv2(flts_b{1,1}{1}, flts_b{1,1}{2}, ch00, 'same') ...
        + conv2(flts_b{1,2}{1}, flts_b{1,2}{2}, ch01, 'same') ...
        + conv2(flts_b{1,3}{1}, flts_b{1,3}{2}, ch10, 'same') ...
        + conv2(flts_b{1,4}{1}, flts_b{1,4}{2}, ch11, 'same') + g00;
    
    b(1:2:end,2:2:end) = conv2(flts_b{2,1}{1}, flts_b{2,1}{2}, ch00, 'same') ...
        + conv2(flts_b{2,2}{1}, flts_b{2,2}{2}, ch01, 'same') ...
        + conv2(flts_b{2,3}{1}, flts_b{2,3}{2}, ch10, 'same') ...
        + conv2(flts_b{2,4}{1}, flts_b{2,4}{2}, ch11, 'same') + g01;
    
    b(2:2:end,2:2:end) = conv2(flts_b{3,1}{1}, flts_b{3,1}{2}, ch00, 'same') ...
        + conv2(flts_b{3,2}{1}, flts_b{3,2}{2}, ch01, 'same') ...
        + conv2(flts_b{3,3}{1}, flts_b{3,3}{2}, ch10, 'same') ...
        + conv2(flts_b{3,4}{1}, flts_b{3,4}{2}, ch11, 'same') + g11;
    
    % if we need to have higher-order approximations, for improved
    % precision but at the price of more computation
    for n = 2 : approx_rank
        b(1:2:end,1:2:end) = conv2(flts_b{1,1}{2*n-1}, flts_b{1,1}{2*n}, ch00, 'same') ...
            + conv2(flts_b{1,2}{2*n-1}, flts_b{1,2}{2*n}, ch01, 'same') ...
            + conv2(flts_b{1,3}{2*n-1}, flts_b{1,3}{2*n}, ch10, 'same') ...
            + conv2(flts_b{1,4}{2*n-1}, flts_b{1,4}{2*n}, ch11, 'same') + b(1:2:end,1:2:end);
        
        b(1:2:end,2:2:end) = conv2(flts_b{2,1}{2*n-1}, flts_b{2,1}{2*n}, ch00, 'same') ...
            + conv2(flts_b{2,2}{2*n-1}, flts_b{2,2}{2*n}, ch01, 'same') ...
            + conv2(flts_b{2,3}{2*n-1}, flts_b{2,3}{2*n}, ch10, 'same') ...
            + conv2(flts_b{2,4}{2*n-1}, flts_b{2,4}{2*n}, ch11, 'same') + b(1:2:end,2:2:end);
        
        b(2:2:end,2:2:end) = conv2(flts_b{3,1}{2*n-1}, flts_b{3,1}{2*n}, ch00, 'same') ...
            + conv2(flts_b{3,2}{2*n-1}, flts_b{3,2}{2*n}, ch01, 'same') ...
            + conv2(flts_b{3,3}{2*n-1}, flts_b{3,3}{2*n}, ch10, 'same') ...
            + conv2(flts_b{3,4}{2*n-1}, flts_b{3,4}{2*n}, ch11, 'same') + b(2:2:end,2:2:end);
    end
end

b(2:2:end, 1:2:end) = b10;
b(b < 0) = 0;
b(b > 255) = 255;

xh = cat(3, r, g, b);

t = toc;

