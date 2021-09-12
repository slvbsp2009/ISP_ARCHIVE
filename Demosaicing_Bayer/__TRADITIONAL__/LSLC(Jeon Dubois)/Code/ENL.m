% Demosaicking of Noisy Bayer-Sampled Color Images with Least-Squares
% Luma-Chroma Demultiplexing and Noise Level Estimation
%
% Perform estimating noise level in CFAN 
% 
% IEEE Trans. Image Processing (submitted)
% This software is for provided for non-commercial and research purposes only
% Copyright Eric Dubois (edubois@site.uottawa.ca), University of Ottawa 2011 
% *****************

function esigma = ENL(CFAn, CAorEA, KorL)

MO_CA = 1/0.97414;
MO_EA = 1/0.83893;

AO_CA_K = 10.2655 - 12.0902;
AO_EA_K = 10.2655 - 13.5570;
AO_CA_L = 10.2655 - 12.9975;
AO_EA_L = 10.2655 - 14.8415;

Wval=3;
sval=3;
selWval=5;
idx = 0;

MOmin = 1.8700;
AOminKodak = -0.5177;
AOminLC = -1.2514;
MOmedian = 1.2000;
AOmedianKodak = -4.4340;
AOmedianLC = -5.4659;

alphaR = 1.8523;
alphaG = 0.6891;
alphaB = 1.0000;

for numlist = [111 222 333 444 555]
    numcurrent = numlist;
    numf= floor(numcurrent/100);
    nums= floor(floor((numcurrent/100 - floor(numcurrent/100))*100)/10) ;
    numt= numlist-floor(numcurrent/10)*10 ;

    numlist(1)=numf;
    numlist(2)=nums;
    numlist(3)=numt;

    num1=numlist(1);
    num2=numlist(2);
    num3=numlist(3);

    S = size(CFAn); N1 = S(1); N2 = S(2);
    img1n = CFAn(1:2:N1,1:2:N2);
    imrn = CFAn(1:2:N1,2:2:N2);
    imbn = CFAn(2:2:N1,1:2:N2);
    img2n = CFAn(2:2:N1,2:2:N2);

    s1 = size(img1n,1);
    s2 = size(img1n,2);

    cLB = round(Wval/2);
    rLB = (Wval-1)/2;

    if(selWval == 5)
        mp1 = [0 -2 0 -1 0 1 0 2];
        mp2 = [-2 0 -1 0 1 0 2 0];
        mp3 = [-2 -2 -1 -1 1 1 2 2];
        mp4 = [2 -2 1 -1 -1 1 -2 2];
        mp5 = [2 0 1 0 0 1 0 2];
        mp6 = [0 -2 0 -1 1 0 2 0];
        mp7 = [0 -2 0 -1 -1 0 -2 0];
        mp8 = [-2 0 -1 0 0 1 0 2];
    elseif(selWval == 3)
        mp1 = [0 -1 0 1];
        mp2 = [-1 0 1 0];
        mp3 = [-1 -1 1 1];
        mp4 = [1 -1 -1 1];
        mp5 = [1 0 0 1];
        mp6 = [0 -1 1 0];
        mp7 = [0 -1 -1 0];
        mp8 = [-1 0 0 1];
    end

    g1rec = img1n;
    rrec = imrn;
    brec = imbn;
    g2rec = img2n;

    % homogeneity measurement 
    for ki=0:ceil(s1/Wval)-2
        for kj=0:ceil(s2/Wval)-2
            addg1rec=0;
            addrrec=0;
            addbrec=0;
            addg2rec=0;
            if ( (ki*Wval+cLB <= 2) | (ki*Wval+cLB >= (s1-2)) | (kj*Wval+cLB <= 2) | (kj*Wval+cLB >= (s2-2)) ) 
                addg1rec = 1;
                addrrec = 1;
                addbrec = 1;
                addg2rec = 1;
            else
                for hhh=1:8
                    hhhh = hhh;
                    if hhhh==1
                        mp=mp1;
                    elseif hhhh==2
                        mp=mp2;
                    elseif hhhh==3
                        mp=mp3;
                    elseif hhhh==4
                        mp=mp4;
                    elseif hhhh==5
                        mp=mp5;
                    elseif hhhh==6
                        mp=mp6;
                    elseif hhhh==7
                        mp=mp7;
                    elseif hhhh==8
                        mp=mp8;
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if(selWval == 5)
                        addg1rec = addg1rec + ( -g1rec(ki*Wval+cLB+mp(1),kj*Wval+cLB+mp(2)) - g1rec(ki*Wval+cLB+mp(3),kj*Wval+cLB+mp(4))...
                                    -g1rec(ki*Wval+cLB+mp(5),kj*Wval+cLB+mp(6)) - g1rec(ki*Wval+cLB+mp(7),kj*Wval+cLB+mp(8))...
                                    +4*g1rec(ki*Wval+cLB,kj*Wval+cLB));
                        addrrec = addrrec + ( -rrec(ki*Wval+cLB+mp(1),kj*Wval+cLB+mp(2)) - rrec(ki*Wval+cLB+mp(3),kj*Wval+cLB+mp(4))...
                                    -rrec(ki*Wval+cLB+mp(5),kj*Wval+cLB+mp(6)) - rrec(ki*Wval+cLB+mp(7),kj*Wval+cLB+mp(8))...
                                    +4*rrec(ki*Wval+cLB,kj*Wval+cLB));
                        addbrec = addbrec + ( -brec(ki*Wval+cLB+mp(1),kj*Wval+cLB+mp(2)) - brec(ki*Wval+cLB+mp(3),kj*Wval+cLB+mp(4))...
                                    -brec(ki*Wval+cLB+mp(5),kj*Wval+cLB+mp(6)) - brec(ki*Wval+cLB+mp(7),kj*Wval+cLB+mp(8))...
                                    +4*brec(ki*Wval+cLB,kj*Wval+cLB));
                        addg2rec = addg2rec + ( -g2rec(ki*Wval+cLB+mp(1),kj*Wval+cLB+mp(2)) - g2rec(ki*Wval+cLB+mp(3),kj*Wval+cLB+mp(4))...
                                    -g2rec(ki*Wval+cLB+mp(5),kj*Wval+cLB+mp(6)) - g2rec(ki*Wval+cLB+mp(7),kj*Wval+cLB+mp(8))...
                                    +4*g2rec(ki*Wval+cLB,kj*Wval+cLB));
                    elseif(selWval == 3)
                        addg1rec = addg1rec + ( -g1rec(ki*Wval+cLB+mp(1),kj*Wval+cLB+mp(2)) - g1rec(ki*Wval+cLB+mp(3),kj*Wval+cLB+mp(4))...
                                    +2*g1rec(ki*Wval+cLB,kj*Wval+cLB));
                        addrrec = addrrec + ( -rrec(ki*Wval+cLB+mp(1),kj*Wval+cLB+mp(2)) - rrec(ki*Wval+cLB+mp(3),kj*Wval+cLB+mp(4))...
                                    +2*rrec(ki*Wval+cLB,kj*Wval+cLB));
                        addbrec = addbrec + ( -brec(ki*Wval+cLB+mp(1),kj*Wval+cLB+mp(2)) - brec(ki*Wval+cLB+mp(3),kj*Wval+cLB+mp(4))...
                                    +2*brec(ki*Wval+cLB,kj*Wval+cLB));
                        addg2rec = addg2rec + ( -g2rec(ki*Wval+cLB+mp(1),kj*Wval+cLB+mp(2)) - g2rec(ki*Wval+cLB+mp(3),kj*Wval+cLB+mp(4))...
                                    +2*g2rec(ki*Wval+cLB,kj*Wval+cLB));
                    end
                end                                    
            end                    
            G1di(ki+1,kj+1) = addg1rec;
            Rdi(ki+1,kj+1) = addrrec;
            Bdi(ki+1,kj+1) = addbrec;
            G2di(ki+1,kj+1) = addg2rec;
        end
    end 

    g1Tdi = abs(G1di);
    rTdi = abs(Rdi);
    bTdi = abs(Bdi);
    g2Tdi = abs(G2di);
    idx=idx+1;       

    sortg1Tdi=sort(g1Tdi(:),1);
    sortg1Tdi1 = sortg1Tdi(num1);
    sortg1Tdi2 = sortg1Tdi(num2);
    sortg1Tdi3 = sortg1Tdi(num3);
    sortrTdi=sort(rTdi(:),1);
    sortrTdi1 = sortrTdi(num1);
    sortrTdi2 = sortrTdi(num2);
    sortrTdi3 = sortrTdi(num3);
    sortbTdi=sort(bTdi(:),1);
    sortbTdi1 = sortbTdi(num1);
    sortbTdi2 = sortbTdi(num2);
    sortbTdi3 = sortbTdi(num3);
    sortg2Tdi=sort(g2Tdi(:),1);
    sortg2Tdi1 = sortg2Tdi(num1);
    sortg2Tdi2 = sortg2Tdi(num2);
    sortg2Tdi3 = sortg2Tdi(num3); 

    indg1Tdi1 = find(g1Tdi == sortg1Tdi1);
    indg1Tdi2 = find(g1Tdi == sortg1Tdi2);
    indg1Tdi3 = find(g1Tdi == sortg1Tdi3);
    indrTdi1 = find(rTdi == sortrTdi1);
    indrTdi2 = find(rTdi == sortrTdi2);
    indrTdi3 = find(rTdi == sortrTdi3);
    indbTdi1 = find(bTdi == sortbTdi1);
    indbTdi2 = find(bTdi == sortbTdi2);
    indbTdi3 = find(bTdi == sortbTdi3);
    indg2Tdi1 = find(g2Tdi == sortg2Tdi1);
    indg2Tdi2 = find(g2Tdi == sortg2Tdi2);
    indg2Tdi3 = find(g2Tdi == sortg2Tdi3);

    ss1=size(g1Tdi,1);
    ss2=size(g1Tdi,2);
    g1Tdiim = zeros(ss1,ss2);
    rTdiim = zeros(ss1,ss2);
    bTdiim = zeros(ss1,ss2);
    g2Tdiim = zeros(ss1,ss2);
    g1Tdiim(indg1Tdi1)=1;
    g1Tdiim(indg1Tdi2)=2;
    g1Tdiim(indg1Tdi3)=3;
    rTdiim(indrTdi1)=1;
    rTdiim(indrTdi2)=2;
    rTdiim(indrTdi3)=3;
    bTdiim(indbTdi1)=1;
    bTdiim(indbTdi2)=2;
    bTdiim(indbTdi3)=3;
    g2Tdiim(indg2Tdi1)=1;
    g2Tdiim(indg2Tdi2)=2;
    g2Tdiim(indg2Tdi3)=3;

    mg1reclb = zeros(ceil(s1/Wval)-2, ceil(s2/Wval)-2);
    mrreclb = zeros(ceil(s1/Wval)-2, ceil(s2/Wval)-2);
    mbreclb = zeros(ceil(s1/Wval)-2, ceil(s2/Wval)-2);
    mg2reclb = zeros(ceil(s1/Wval)-2, ceil(s2/Wval)-2);

    g1num = 0;
    for ki=0:ceil(s1/Wval)-2
        for kj=0:ceil(s2/Wval)-2          
            if( g1Tdiim(ki+1,kj+1) == 1 | g1Tdiim(ki+1,kj+1) == 2 | g1Tdiim(ki+1,kj+1) == 3 ) 
                g1reclb = g1rec(ki*Wval+cLB-rLB:ki*Wval+cLB+rLB,kj*Wval+cLB-rLB:kj*Wval+cLB+rLB);
                mg1reclb(ki+1,kj+1)= sum(sum(g1reclb))/Wval^2;
                g1num = g1num +1;
            end
        end
    end            

    rnum = 0;
    for ki=0:ceil(s1/Wval)-2
        for kj=0:ceil(s2/Wval)-2          
            if( rTdiim(ki+1,kj+1) == 1 | rTdiim(ki+1,kj+1) == 2 | rTdiim(ki+1,kj+1) == 3 ) 
                rreclb = rrec(ki*Wval+cLB-rLB:ki*Wval+cLB+rLB,kj*Wval+cLB-rLB:kj*Wval+cLB+rLB);
                mrreclb(ki+1,kj+1)= sum(sum(rreclb))/Wval^2;
                rnum = rnum +1;
            end
        end
    end        

    bnum = 0;
    for ki=0:ceil(s1/Wval)-2
        for kj=0:ceil(s2/Wval)-2          
            if( bTdiim(ki+1,kj+1) == 1 | bTdiim(ki+1,kj+1) == 2 | bTdiim(ki+1,kj+1) == 3 ) 
                breclb = brec(ki*Wval+cLB-rLB:ki*Wval+cLB+rLB,kj*Wval+cLB-rLB:kj*Wval+cLB+rLB);
                mbreclb(ki+1,kj+1)= sum(sum(breclb))/Wval^2;
                bnum = bnum +1;
            end
        end
    end   

    g2num = 0;
    for ki=0:ceil(s1/Wval)-2
        for kj=0:ceil(s2/Wval)-2          
            if( g2Tdiim(ki+1,kj+1) == 1 | g2Tdiim(ki+1,kj+1) == 2 | g2Tdiim(ki+1,kj+1) == 3 ) 
                g2reclb = g2rec(ki*Wval+cLB-rLB:ki*Wval+cLB+rLB,kj*Wval+cLB-rLB:kj*Wval+cLB+rLB);
                mg2reclb(ki+1,kj+1)= sum(sum(g2reclb))/Wval^2;
                g2num = g2num +1;
            end
        end
    end   

    vg1reclb= zeros(ceil(s1/Wval)-2, ceil(s2/Wval)-2);
    vrreclb= zeros(ceil(s1/Wval)-2, ceil(s2/Wval)-2);
    vbreclb= zeros(ceil(s1/Wval)-2, ceil(s2/Wval)-2);
    vg2reclb= zeros(ceil(s1/Wval)-2, ceil(s2/Wval)-2);

    g1num = 0;            
    for ki=0:ceil(s1/Wval)-2
        for kj=0:ceil(s2/Wval)-2
            if( g1Tdiim(ki+1,kj+1) == 1 | g1Tdiim(ki+1,kj+1) == 2 | g1Tdiim(ki+1,kj+1) == 3 )
                g1reclb2 = g1rec(ki*Wval+cLB-rLB:ki*Wval+cLB+rLB,kj*Wval+cLB-rLB:kj*Wval+cLB+rLB) - mg1reclb(ki+1,kj+1);
                vg1reclb(ki+1,kj+1)= sum(sum(g1reclb2.*g1reclb2))/(Wval^2 - 1);
                g1num = g1num +1;                            
            end
        end
    end

    rnum = 0;            
    for ki=0:ceil(s1/Wval)-2
        for kj=0:ceil(s2/Wval)-2
            if( rTdiim(ki+1,kj+1) == 1 | rTdiim(ki+1,kj+1) == 2 | rTdiim(ki+1,kj+1) == 3 )
                rreclb2 = rrec(ki*Wval+cLB-rLB:ki*Wval+cLB+rLB,kj*Wval+cLB-rLB:kj*Wval+cLB+rLB) - mrreclb(ki+1,kj+1);
                vrreclb(ki+1,kj+1)= sum(sum(rreclb2.*rreclb2))/(Wval^2 - 1);
                rnum = rnum +1;                            
            end
        end
    end

    bnum = 0;            
    for ki=0:ceil(s1/Wval)-2
        for kj=0:ceil(s2/Wval)-2
            if( bTdiim(ki+1,kj+1) == 1 | bTdiim(ki+1,kj+1) == 2 | bTdiim(ki+1,kj+1) == 3 )
                breclb2 = brec(ki*Wval+cLB-rLB:ki*Wval+cLB+rLB,kj*Wval+cLB-rLB:kj*Wval+cLB+rLB) - mbreclb(ki+1,kj+1);
                vbreclb(ki+1,kj+1)= sum(sum(breclb2.*breclb2))/(Wval^2 - 1);
                bnum = bnum +1;                            
            end
        end
    end

    g2num = 0;            
    for ki=0:ceil(s1/Wval)-2
        for kj=0:ceil(s2/Wval)-2
            if( g2Tdiim(ki+1,kj+1) == 1 | g2Tdiim(ki+1,kj+1) == 2 | g2Tdiim(ki+1,kj+1) == 3 )
                g2reclb2 = g2rec(ki*Wval+cLB-rLB:ki*Wval+cLB+rLB,kj*Wval+cLB-rLB:kj*Wval+cLB+rLB) - mg2reclb(ki+1,kj+1);
                vg2reclb(ki+1,kj+1)= sum(sum(g2reclb2.*g2reclb2))/(Wval^2 - 1);
                g2num = g2num +1;                            
            end
        end
    end

    if(g1num == 0) g1num=0.000001;
    end 
    if(rnum == 0) rnum=0.000001;
    end
    if(bnum == 0) bnum=0.000001;
    end
    if(g2num == 0) g2num=0.000001;
    end 

    vg1 = sum(sum(vg1reclb))/g1num;
    vr = sum(sum(vrreclb))/rnum;
    vb = sum(sum(vbreclb))/bnum;
    vg2 = sum(sum(vg2reclb))/g2num;         

    result_alpha_withoutalphadiv(idx,:) = [sqrt(vg1)*255 sqrt(vr)*255 sqrt(vb)*255 sqrt(vg2)*255];
    result_alpha(idx,:) = [sqrt(vg1)*255/sqrt(alphaG) sqrt(vr)*255/sqrt(alphaR) sqrt(vb)*255/sqrt(alphaB) sqrt(vg2)*255/sqrt(alphaG)];            
end

rawad  = result_alpha_withoutalphadiv;
ra = result_alpha;    

Gdiv1 = (sum(ra(:,1)) - max(ra(:,1)) - min(ra(:,1)))/3;
Rdiv1 = (sum(ra(:,2)) - max(ra(:,2)) - min(ra(:,2)))/3;
Bdiv1 = (sum(ra(:,3)) - max(ra(:,3)) - min(ra(:,3)))/3;
Gdiv2 = (sum(ra(:,4)) - max(ra(:,4)) - min(ra(:,4)))/3;

Gundiv1 = (sum(rawad(:,1)) - max(rawad(:,1)) - min(rawad(:,1)))/3;
Rundiv1 = (sum(rawad(:,2)) - max(rawad(:,2)) - min(rawad(:,2)))/3;
Bundiv1 = (sum(rawad(:,3)) - max(rawad(:,3)) - min(rawad(:,3)))/3;
Gundiv2 = (sum(rawad(:,4)) - max(rawad(:,4)) - min(rawad(:,4)))/3;

DIV = [Gdiv1 Rdiv1 Bdiv1 Gdiv2];
UNDIV = [Gundiv1 Rundiv1 Bundiv1 Gundiv2];

UNDIV_Bundiv1 = [Gundiv1/Bundiv1 Rundiv1/Bundiv1 Bundiv1/Bundiv1 Gundiv2/Bundiv1];
alphaRrec =  (Rundiv1/Bundiv1)^2;
alphaGrec =  ((Gundiv1+Gundiv2)/(2*Bundiv1))^2;

[alphaR alphaG alphaB];
[alphaRrec alphaGrec alphaB];

DIVrec = [sqrt(alphaGrec)*Gundiv1 sqrt(alphaRrec)*Rundiv1 Bundiv1 sqrt(alphaGrec)*Gundiv2];


if (CAorEA == 'CA' & KorL == 'K') 
    ['CA' 'K'];
    esigma = MO_CA*median(DIV)+AO_CA_K;
elseif (CAorEA == 'CA' & KorL == 'L') 
    ['CA' 'L'];
    esigma = MO_CA*median(DIV)+AO_CA_L;
elseif (CAorEA == 'EA' & KorL == 'K') 
    ['EA' 'K'];
    esigma = MO_EA*median(DIVrec)+AO_EA_K;
elseif (CAorEA == 'EA' & KorL == 'L') 
    ['EA' 'L'];
    esigma = MO_EA*median(DIVrec)+AO_EA_L;
end

