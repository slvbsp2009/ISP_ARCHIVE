function [ denoisedpatch ] = denoise_block( noisyblock, Par_common, Par_S )
%DENOISE_BLOCK 이 함수의 요약 설명 위치
%   자세한 설명 위치
numblock = size(noisyblock, 4);
denoisedpatch = zeros(Par_common.size_patch, Par_common.size_patch, 1, numblock);
numbatch = floor((numblock-1)/Par_common.batch_size)+1;
numlast = numblock - (numbatch-1) * Par_common.batch_size;

dtxt = textread(Par_S.last_model,'%s','delimiter','\n','whitespace','');
fpo = fopen(Par_S.last_model, 'w');
linenum = 1;
for i=1:length(dtxt)
    if(linenum == 3 )
        fprintf(fpo, 'input_dim: %d\n', numlast);
    else
        fprintf(fpo, dtxt{i, 1});
        fprintf(fpo, '\n');
    end
    linenum = linenum+1;
end
fclose(fpo);

net_S = caffe.Net(Par_S.net_model, Par_S.net_weights, 'test');
net_S_Last = caffe.Net(Par_S.last_model, Par_S.net_weights, 'test');
for i = 1:numbatch-1
    subim_input = noisyblock(:, :, :, (i-1)*Par_common.batch_size+1:i*Par_common.batch_size);
    im_data = {subim_input};
    resu = net_S.forward(im_data);
    denoisedpatch(:, :, :, (i-1)*Par_common.batch_size+1:i*Par_common.batch_size) = resu{1, 1};    
end

subim_input = noisyblock(:, :, :, (numbatch-1)*Par_common.batch_size+1:end);
im_data = {subim_input};
resu = net_S_Last.forward(im_data);
denoisedpatch(:, :, :, (numbatch-1)*Par_common.batch_size+1:end) = resu{1, 1};    
caffe.reset_all;        
end

