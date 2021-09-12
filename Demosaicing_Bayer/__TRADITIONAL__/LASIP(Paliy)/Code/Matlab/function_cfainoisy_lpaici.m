function out = function_cfainoisy_lpaici(in,add_noise,CFA_phaseshift)

% Gaussian noise
%
% The demosaicing of input data "in"
% CFA_phaseshift = 1:
%    A--The input mosaic image, Bayer Pattern as follows
%    G R G R...
%    B G B G...
%
% CFA_phaseshift = 2:
%    A--The input mosaic image, Bayer Pattern as follows
%    R G R...
%    G B G...
%

% make Bayer pattern
if nargin<3, CFA_phaseshift = 1; end;
if nargin<2, add_noise = 0; end;

in = double(in);


switch CFA_phaseshift,
    case 1;
    case 2
        tmpin = zeros([size(in,1) size(in,2)+2 size(in,3)]);
        tmpin(:,2:end-1,:) = in;
        in = tmpin;
end;


switch add_noise,
    case 0
    case 1 % Poissonian
        chi = 0.5447;
        
        randn('state',890736434); rand('state',03465807634);
        in = poissrnd(in*chi)/chi;
        
    case 2 % Gaussian
        % sigma = 0.05;
        sigma = 12.75;
        
        % in = in./255;
        randn('state',890736434);
        in = in + sigma.*randn(size(in));
    case 3 % Hirakawa 2005
        k0 = 10;
        k1 = 0.1;

        % k0 = 25;
        % k1 = 0.0;

        % k0 = 0.0;
        % k1 = 0.0;
        
        randn('state',890736434);
        sigma = (k0 + k1.*in);
        in = in + sigma.*randn(size(in));
end;


[N,M,ch]=size(in);
if ch==3
    X=zeros(N,M);
    X(1:2:N,1:2:M) = in(1:2:N,1:2:M,2);
    X(2:2:N,2:2:M) = in(2:2:N,2:2:M,2);
    X(1:2:N,2:2:M) = in(1:2:N,2:2:M,1);
    X(2:2:N,1:2:M) = in(2:2:N,1:2:M,3);
end

if ch==1
    X=zeros(N,M);
    X(1:2:N,1:2:M) = in(1:2:N,1:2:M,1);
    X(2:2:N,2:2:M) = in(2:2:N,2:2:M,1);
    X(1:2:N,2:2:M) = in(1:2:N,2:2:M,1);
    X(2:2:N,1:2:M) = in(2:2:N,1:2:M,1);
end


switch add_noise,
    case 0
    case 1 % Poissonian
        sigma = sqrt(X/chi);
    case 2 % Gaussian
        outG1 = X(1:2:N,1:2:M);
        outG2 = X(2:2:N,2:2:M);
        outR  = X(1:2:N,2:2:M);
        outB  = X(2:2:N,1:2:M);
        
        sg = function_stdEst2D([outG1 outG2],2);
        sr = function_stdEst2D(outR,2);
        sb = function_stdEst2D(outB,2);
        
        sigma(1:2:N,1:2:M) = sg; sigma(1:2:N,2:2:M) = sr;
        sigma(2:2:N,1:2:M) = sb; sigma(2:2:N,2:2:M) = sg;
        
    case 3 % Hirakawa 2005
        sigma = (k0 + k1.*X);        
end;

%%
gamma_d = 1.5;
gamma_D = 1.0;
out = do_noisycfai(X,sigma,gamma_d,gamma_D);

%%
switch add_noise,
    case 0
    case 1 % Poissonian
    case 2 % Gaussian
        % out = out.*255;
    case 3 % Hirakawa 2005
end;

switch CFA_phaseshift,
    case 1;
    case 2
        tmpout = out(:,2:end-1,:);
        out = tmpout;
end;

