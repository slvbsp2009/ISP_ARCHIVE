% Spatially Adaptive Color Filter Array Interpolation based on the LPA-ICI
% 

warning off all
clear all

mean = zeros([3 3]);
%   07 - window
%   19 - lighthouse
%   23 - parrots

ImSet = [1:24];
ImSet = [19];
for j=ImSet,

    if j>9,
        fname = ['kodim',num2str(j),'.png'];
    else
        fname = ['kodim0',num2str(j),'.png'];
    end;

    X = double(imread(fname));
        
    Y = X;[N,M,ch]=size(X);
    Y(1:2:N,1:2:M) = X(1:2:N,1:2:M,2);
    Y(2:2:N,2:2:M) = X(2:2:N,2:2:M,2);
    Y(2:2:N,1:2:M) = X(2:2:N,1:2:M,3);
    Y(1:2:N,2:2:M) = X(1:2:N,2:2:M,1);
    
    % CFA_phaseshift = 1:
    %    G R G R...
    %    B G B G...
    %
    % CFA_phaseshift = 2:
    %    R G R...
    %    G B G...
    
    tic
    CFA_phaseshift = 1;
    Res = function_cfai_lpaici(Y,CFA_phaseshift);
    % Res = function_cfai_ha(Y,CFA_phaseshift);
    toc
    mean(3,2) = mean(3,2) + toc;
    % ------------------------------------
    % Results
    % ------------------------------------
    Res = min(max(Res,0),255);
    border = 15;
    disp('__________________________________')
    if j<=25,
        for i=1:3,
            if j<25,
                Final_Errors = function_Errors(X(border+1:end-border,border+1:end-border,i),...
                    Res(border+1:end-border,border+1:end-border,i),...
                    X(border+1:end-border,border+1:end-border,i))';

                disp(['Im ',num2str(j),'; Ch ',num2str(i),'; PSNR = ', num2str(Final_Errors(3))])
                mean(1,i) = mean(1,i) + Final_Errors(4);
                mean(2,i) = mean(2,i) + Final_Errors(3);
            end;
        end;
    end;

    figure, imshow(uint8(Res(:,:,:)));
    title(['PSNR Red: ',num2str(psnr(Res(border+1:end-border,border+1:end-border,1),X(border+1:end-border,border+1:end-border,1))),...
        '; Green: ',num2str(psnr(Res(border+1:end-border,border+1:end-border,2),X(border+1:end-border,border+1:end-border,2))),...
        '; Blue: ',num2str(psnr(Res(border+1:end-border,border+1:end-border,3),X(border+1:end-border,border+1:end-border,3)))]);
end;

disp('--------- FINAL RESULTS ---------')
mean./length(ImSet(:))
