%--------------------------------------------------------------------------
%
%  Yue M. Lu
%  Ecole Polytechnique Federale de Lausanne (EPFL)
%
%--------------------------------------------------------------------------
%
%  Lipschitz_const.m
%
%  First created: 01-11-2009
%  Last modified: 06-09-2009
%
%--------------------------------------------------------------------------

function q = Lipschitz_const(L, cc, N)

%  Estimate the Lipschitz constant for the mapping associated with the AP
%  demosaicking algorithm.
%
%  INPUT
%    L: the lowpass filter used in the algorithm
%
%    cc: the coordinates of the center of L
%
%    N: the window size for calculating the DFT (N should be chosen to be a
%    large number to ensure the precision of the estimated Lipschitz
%    constant.

if (N < max(size(L))) || (mod(N, 2) ~= 0)
    error('N must be an even number larger than the dimension of the filter h.');
end

% T matrix = 
%
% | H00(z)     H10(z)z_1^{-1}     H11(z)z_1^{-1)z_2^{-1} |
% |                                                      |
% | H10(z)     H00(z)             H01(z)z_2^{-1}         |
% |                                                      |
% | H11(z)     H01(z)             H00(z)                 |
%

L_polymtx = get_L_polymtx(L, cc, N, N);
T_mtx = L_polymtx([1 3 4], [1 3 4], :);

q = zeros(size(T_mtx, 3), 1);

for n = 1 : size(T_mtx, 3)
   q(n) = norm(T_mtx(:,:,n));
end

q = max(q);
