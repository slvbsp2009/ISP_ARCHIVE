%--------------------------------------------------------------------------
%
%  Yue M. Lu
%  Ecole Polytechnique Federale de Lausanne (EPFL)
%
%--------------------------------------------------------------------------
%
%  test_Lipschitz_const.m
%
%  First created: 01-11-2009
%  Last modified: 06-09-2009
%
%--------------------------------------------------------------------------

%  Estimate the Lipschitz constant of the mapping defined by the AP
%  algorithm


a0 = [1 2 1] / 4;
s0 = [-1 2 6 2 -1] / 8;

L = conv(a0, s0);

% Get the 2-D filter by tensor product
L = kron(L, L');

N = 2048; % for a quicker answer, use N = 256

tic
q = Lipschitz_const(L, (size(L) + [1 1])/2, N)
toc
