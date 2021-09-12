%--------------------------------------------------------------------------
%
%  Yue M. Lu
%  Ecole Polytechnique Federale de Lausanne (EPFL)
%
%--------------------------------------------------------------------------
%
%  plot_lowpass_frequency_response.m
%
%  First created: 12-23-2008
%  Last modified: 06-09-2009
%
%--------------------------------------------------------------------------

% We plot the magnitude frequency response of L = A_0 * S_0

ShowColor = 0;
IsPrint = 0;

% The resolution of the frequency response
N = 48;


a0 = [1 2 1] / 4;
s0 = [-1 2 6 2 -1] / 8;

l = conv(a0, s0);

% Get the 2-D filter by tensor product
l = kron(l, l');

L = zeros(N);
L(1 : size(l, 1), 1 : size(l, 2)) = l;
L = abs(fftshift(fft2(L)));

h = figure
[fgrid_x, fgrid_y] = meshgrid([-N/2+1 : N/2] * 2 * pi / N);
mesh(fgrid_x, fgrid_y, L);
axis tight
view(-45, 50);

if ~ShowColor
    cm_black = colormap;
    cm_black(:) = 0;
    colormap(cm_black);
end


set(gca,'ZTick', 0:0.5:1)
set(gca,'XTick',[fgrid_x(1),0,pi])
set(gca,'XTickLabel',{'-pi','0','pi'})
set(gca,'YTick',[fgrid_x(1),0,pi])
set(gca,'YTickLabel',{'-pi','0','pi'})

if IsPrint
    set(0,'defaulttextinterpreter','none')
    laprint(h, ['frequency_response_lowpass_L' ], 'color', 'on', 'width', 18);
end