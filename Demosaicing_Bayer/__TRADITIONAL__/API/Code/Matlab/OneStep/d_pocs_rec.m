% Recording the mse value at each iteration

% Modified by Yue M. Lu
% 04-10-2009
% (See d_pocs.m for the original version.)


function [R, R_init, mse_list] = d_pocs_rec(X, N_iter, varargin)

% G R
% B G

if nargin == 2
    mode = 1;   % obtain the convergence value with initial bilinear interpolation
else
    mode = 2;   % record the mse at each iteration
    R0 = varargin{1};
    R_conv = varargin{2};
end

mse_list = zeros(N_iter+1, 1);

%%%%% Initial interpolation of the color channels
RGB = double(interp_edgeG(X));

%%%%% Initial Red, green, and blue channel assignments
R = RGB(:,:,1); 
G = RGB(:,:,2); 
B = RGB(:,:,3); 

%%%%% Filters that will be used in subband decomposition 
h0 = [1 2 1]/4;
h1 = [1 -2 1]/4;
g0 = [-1 2 6 2 -1]/8;
g1 = [1 2 -6 2 1]/8;

%%%% Update Green channel
Rd = X(1:2:end,2:2:end); 
Bd = X(2:2:end,1:2:end);
Gd_R = RGB(1:2:end,2:2:end,2);
Gd_B = RGB(2:2:end,1:2:end,2);
%
[CA_Rr,CH_Rr,CV_Rr,CD_Rr] = rdwt2(Rd,h0,h1);
[CA_Gr,CH_Gr,CV_Gr,CD_Gr] = rdwt2(Gd_R,h0,h1); 
[CA_Bb,CH_Bb,CV_Bb,CD_Bb] = rdwt2(Bd,h0,h1);
[CA_Gb,CH_Gb,CV_Gb,CD_Gb] = rdwt2(Gd_B,h0,h1); 
%
Gd_R = ridwt2(CA_Gr, CH_Rr, CV_Rr, CD_Rr, g0,g1);
Gd_B = ridwt2(CA_Gb, CH_Bb, CV_Bb, CD_Bb, g0,g1);
%
G(1:2:end,2:2:end) = Gd_R;  
G(2:2:end,1:2:end) = Gd_B;

G(G < 0) = 0;
G(G > 255) = 255;


% Insert the initial value of R here
if mode == 2
    R = R0;
    mse_list(1) = calc_mse(R, R_conv);
end

R_init = R;

%%%%% Alternating projections algorithm starts here
[CA_G,CH_G,CV_G,CD_G] = rdwt2(G,h0,h1);

for iter=1:N_iter, % iterate
           
   %%%%% DETAIL PROJECTION
   
   %%%%% Decompose into subbands 
   [CA_R,CH_R,CV_R,CD_R] = rdwt2(R,h0,h1);
   
   %[CA_B,CH_B,CV_B,CD_B] = rdwt2(B,h0,h1);

   %%%%% Update detail subbands of R and B  
   %%%
   %%%%% Reconstruct back from subbands
   R = ridwt2(CA_R, CH_G, CV_G, CD_G, g0, g1);
   %B = ridwt2(CA_B, CH_G, CV_G, CD_G, g0, g1);
   
   
   %%%%% OBSERVATION PROJECTION
   
   %%%%% Make sure that R and B channels obey the data 
   R(1:2:end,2:2:end) = X(1:2:end,2:2:end); 
   %B(2:2:end,1:2:end) = X(2:2:end,1:2:end);
   
   if mode == 2
       mse_list(iter+1) = calc_mse(R, R_conv);
   end
      
end


function mse = calc_mse(x, y)

skip = 15;
diff = x(skip+1:end-skip, skip+1:end-skip) - y(skip+1:end-skip, skip+1:end-skip);

mse = mean(diff(:).^2);

