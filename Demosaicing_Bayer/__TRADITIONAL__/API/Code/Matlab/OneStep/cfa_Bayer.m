%--------------------------------------------------------------------------
%
%  Yue M. Lu
%  Ecole Polytechnique Federale de Lausanne (EPFL)
%
%--------------------------------------------------------------------------
%
%  cfa_Bayer.m
%
%  First created: 12-04-2007
%  Last modified: 06-09-2009
%
%--------------------------------------------------------------------------

function x_bayer = cfa_Bayer(x)

%  Obtaining the CFA measurement according to the Bayer pattern
% 
%  INPUT
%    x: a full-color image of size M-by-N-by-3
%
%  OUTPUT
%    x_bayer: the CFA measurement of size M-by-N.
%
%  NOTE
%    We assume the following arrangement of the Bayer CFA. Starting from
%    the upper-left corner, we have
%    
%    g r g r ...
%    b g b g ...


x_bayer = x(:,:,2);

% Copy the red pixels
x_bayer(1:2:end, 2:2:end) = x(1:2:end, 2:2:end, 1);

% The blue pixels
x_bayer(2:2:end, 1:2:end) = x(2:2:end, 1:2:end, 3);

