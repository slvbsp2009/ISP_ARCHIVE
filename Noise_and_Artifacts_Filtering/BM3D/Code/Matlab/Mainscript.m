if exist('$Caffe_Path/matlab/+caffe', 'dir')
  addpath('$Caffe_Path/matlab');
else
  error('Cannot find Matcaffe');
end
% setting
addpath('./BM');
use_gpu=1;
% Set caffe mode
if exist('use_gpu', 'var') && use_gpu
    caffe.set_mode_gpu();
    gpu_id = 0;  % we will use the first gpu in this demo
    caffe.set_device(gpu_id);
else
    caffe.set_mode_cpu();
end

imglist = dir('./Images/*.png');
Par_common.batch_size = 16;
Par_common.size_patch = 20;
Par_common.weightsSig = 1;
Par_common.stride = 10;
Par_common = Parsetting(Par_common);

Par_Net.net_model = 'deploy_3x3_BN.prototxt';
Par_Net.last_model = 'deploy_3x3_BN_Last.prototxt';
Par_Net.block_member = 4;
Par_Net.search_range = 20;

sigma = 25;
rand('seed', 1);
randn('seed', 1);
resid = fopen(['result_BMCNN.txt'], 'w');

Par_Net.net_weights = ['BMCNN_BM3D.caffemodel'];

for imgidx=1:1
    label = im2double((imread(['./Images/' imglist(imgidx).name])));
    noisy = label+sigma/255*randn(size(label));
    
    [H, W] = size(label);
    t=clock;
    [ignore, pilot] = BM3D(label, noisy, sigma, 'np', 0);    
    finalres = denoise_final(pilot, noisy, Par_common, Par_Net);
    t1=etime(clock,t)
    
    PSNR = psnr(label, finalres)
    SSIM = ssim_index(label*255, finalres*255, [0.01 0.03], ones(8));
    fprintf(resid, [imglist(imgidx).name ' ' num2str(PSNR) ' ' num2str(SSIM) ' ' num2str(t1)]);
    fprintf(resid, '\n');
end
fclose(resid);
