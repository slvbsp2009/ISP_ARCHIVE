function [final] = denoise_final(basic, noisy, Par_common, Par_S)
%DENOISE_FINAL 이 함수의 요약 설명 위치
%   자세한 설명 위치
[H, W] = size(noisy);
[noisyblock1, noisyblock2] = mexBM(basic, noisy, [Par_common.size_patch, Par_common.size_patch, Par_common.stride, Par_S.block_member, Par_S.search_range, true]);
noisyblock = cat(3, noisyblock1, noisyblock2);

denoisedpatch = denoise_block(noisyblock, Par_common, Par_S);

res = zeros(size(noisy));
w = zeros(size(res));

count = 1;
xrange = 1: Par_common.stride : H-Par_common.size_patch+1;
if(xrange(end) ~= H-Par_common.size_patch+1)
    xrange = [xrange H-Par_common.size_patch+1];
end
    
yrange = 1: Par_common.stride : W-Par_common.size_patch+1;
if(yrange(end) ~= W-Par_common.size_patch+1)
    yrange = [yrange W-Par_common.size_patch+1];
end

for x = xrange
    for y = yrange       
        subim_output = noisyblock(:, :, 5, count) - denoisedpatch(:, :, :, count); 
        res(x:x+Par_common.size_patch-1, y:y+Par_common.size_patch-1) = res(x:x+Par_common.size_patch-1, y:y+Par_common.size_patch-1) + (subim_output'.*Par_common.pixel_weights);
        w(x:x+Par_common.size_patch-1, y:y+Par_common.size_patch-1) = w(x:x+Par_common.size_patch-1, y:y+Par_common.size_patch-1) + Par_common.pixel_weights;      
        count = count+1;            
    end
end

final = res./w;

end
