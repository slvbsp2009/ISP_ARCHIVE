
#include "mex.h"
#include "Image.h"
#include <vector>
#include <algorithm>

double *symetrize(const DImage img, int search_range){
	const int width = img.width();
	const int height = img.height();

    const int w = width + 2 * search_range;
    const int h = height + 2 * search_range;
	double *img_sym = (double*)malloc(sizeof(double) * h * w);
	
	int dc = 0;
	int dc_2 = search_range * w + search_range;	
	//! Center of the image
	for (int i = 0; i < height; i++)
		for (int j = 0; j < width; j++, dc++)
			img_sym[dc_2 + i * w + j] = img[dc];
	
	//! Top and bottom
	dc_2 = 0;
	for (int j = 0; j < w; j++, dc_2++)
		for (int i = 0; i < search_range; i++){
			img_sym[dc_2 + i * w] = img_sym[dc_2 + (2 * search_range - i - 1) * w];
			img_sym[dc_2 + (h - i - 1) * w] = img_sym[dc_2 + (h - 2 * search_range + i) * w];
		}
		
	//! Right and left
    dc_2 = 0;
    for (int i = 0; i < h; i++){
		const int di = dc_2 + i * w;
		for (int j = 0; j < search_range; j++){
			img_sym[di + j] = img_sym[di + 2 * search_range - j - 1];
			img_sym[di + w - j - 1] = img_sym[di + w - 2 * search_range + j];
		}
	}
    return img_sym;
}
	
bool ComparaisonFirst(pair<double,unsigned> pair1, pair<double,unsigned> pair2)
{
	return pair1.first < pair2.first;
}


void precompute_BM(
    vector<vector<unsigned> > &patch_table
,   const double *img
,   const unsigned width
,   const unsigned height
,   const unsigned input_size
,   const unsigned block_member
,   const unsigned search_range
,   const int *row_ind, const int row_ind_size
,   const int *col_ind, const int col_ind_size
){
    //! Declarations
    const unsigned Ns = 2 * search_range + 1;
    vector<double> diff_table(width * height);
    vector<vector<double> > sum_table((search_range+1) * Ns, vector<double> (width * height, 40000));
	
    //! For each possible distance, precompute inter-patches distance
	for (int di = 0; di <= search_range; ++di){
		for(int dj = 0; dj < Ns; ++dj){
            const unsigned dk = di * width + dj - search_range * 1;
            const unsigned ddk = di * Ns + dj;

		    for (unsigned i = search_range; i < height - search_range; ++i){
                unsigned k = i * width + search_range;
				for (unsigned j = search_range; j < width - search_range; j++, k++){					
                    diff_table[k] = (img[k + dk] - img[k]) * (img[k + dk] - img[k]);
				}
			}
			const unsigned dn = search_range * width + search_range;
			double value = .0;
			for (unsigned offsetx = 0 ; offsetx < input_size; ++offsetx){
                unsigned offsetxy = offsetx * width + dn;
				for (unsigned offsety = 0; offsety < input_size; ++offsety, ++offsetxy){
					value += diff_table[offsetxy];
				}
			}
			sum_table[ddk][dn] = value;
			

			for (unsigned  j = search_range + 1; j < width - search_range + 1; j++){
                const unsigned ind = search_range * width + j - 1;
                double sum = sum_table[ddk][ind];
                for (unsigned p = 0; p < input_size; p++)
                    sum += diff_table[ind + p * width + input_size] - diff_table[ind + p * width];
                sum_table[ddk][ind + 1] = sum;
            }
			

            for (unsigned i = search_range + 1; i < height - search_range + 1 ; i++)
            {
                const unsigned ind = (i - 1) * width + search_range;
                double sum = sum_table[ddk][ind];
                for (unsigned q = 0; q < input_size; q++)
                    sum += diff_table[ind + input_size * width + q] - diff_table[ind + q];
                sum_table[ddk][ind + width] = sum;

                unsigned k = i * width + search_range + 1;
                unsigned pq = (i + input_size - 1) * width + input_size - 1 + search_range + 1;
                for (unsigned j = search_range + 1; j < width - search_range + 1; j++, k++, pq++)
                {
                    sum_table[ddk][k] =
                          sum_table[ddk][k - 1]
                        + sum_table[ddk][k - width]
                        - sum_table[ddk][k - 1 - width]
                        + diff_table[pq]
                        - diff_table[pq - input_size]
                        - diff_table[pq - input_size * width]
                        + diff_table[pq - input_size - input_size * width];
                }
            }
		}	
	}
	
    //! Precompute Bloc Matching		
    vector<pair<double, unsigned> > table_distance;
    table_distance.reserve(Ns * Ns);
    for (unsigned ind_i = 0; ind_i < row_ind_size; ind_i++){
        for (unsigned ind_j = 0; ind_j < col_ind_size; ind_j++)
        {
			const unsigned ind = ind_i * col_ind_size + ind_j;
            const unsigned k_r = (row_ind[ind_i] + search_range) * width + col_ind[ind_j] + search_range;
            table_distance.clear();
            patch_table[ind].clear();			
			
			for (int dj = 0; dj <  Ns; dj++)
            {
                for (int di = 0; di <= search_range; di++)
					table_distance.push_back(make_pair(sum_table[dj + di * Ns][k_r], dj + (di + search_range) * Ns));

                for (int di = - (int) search_range; di < 0; di++)
					table_distance.push_back(make_pair(sum_table[(Ns-1-dj) + (-di) * Ns][k_r + di * width + dj], dj + (di + search_range) * Ns));
            }



		/*	for (int dj = 0; dj <  Ns; dj++){
				for (int di = 0 ; di < Ns ; di++){
					table_distance.push_back(make_pair(sum_table[dj + di * Ns][k_r], dj + di * Ns));
				}
            }
		*/	
            partial_sort(table_distance.begin(), table_distance.begin() + block_member,
                                            table_distance.end(), ComparaisonFirst);

            for (unsigned n = 0; n < block_member; n++)
                patch_table[ind].push_back(table_distance[n].second);			
        }
    }	
	
}


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	DImage Srcim, Dstim;
	Srcim.LoadMatlabImage(prhs[0]);
	Dstim.LoadMatlabImage(prhs[1]);
	
	int input_size = 21;
	int output_size = 21;
	int step_size = 4;
	int block_member = 4;
	int search_range = 20;
	bool collabo = false;
	
    if(nrhs>2)
    {
		const int* dims=mxGetDimensions(prhs[2]);
		int nPara=dims[0]+dims[1]-1;		
        double* para=(double *)mxGetData(prhs[2]);

        if(nPara>=1)
            input_size=para[0];
        if(nPara>=2)
            output_size=para[1];
        if(nPara>=3)
			step_size=para[2];
		if(nPara>=4)
            block_member=para[3];
		if(nPara>=5)
			search_range=para[4];		
		if(nPara>=6)
			collabo=para[5];
    }

	const int W = Srcim.width();
	const int H = Srcim.height();
	const int C = 1;	
	const int Ns = 2 * search_range + 1;
	int pad_size = (input_size - output_size)/2;
	double *srcdata = Srcim.data();
	double *dstdata = Dstim.data();
	
	int row_ind_size = (H-input_size) / step_size + 1;
	int col_ind_size = (W-input_size) / step_size + 1;
	if((H-input_size) % step_size) row_ind_size++;
	if((W-input_size) % step_size) col_ind_size++;
	int totalblocks = col_ind_size*row_ind_size;
		
	int *row_ind = (int*)malloc(row_ind_size * sizeof(int));
	for(int i = 0; i < row_ind_size; ++i){
		row_ind[i] = i * step_size;	
	}
	if((H - input_size) % step_size) row_ind[row_ind_size-1] = H - input_size;

	int *col_ind = (int*)malloc(col_ind_size * sizeof(int));
	for(int i = 0; i < col_ind_size; ++i){
		col_ind[i] = i * step_size;	
	}
	if((W - input_size) % step_size) col_ind[col_ind_size-1] = W - input_size;

	mwSize nd = 4;
	mwSize dim1[] = {input_size, input_size, block_member, totalblocks};
	mwSize dim2[] = {output_size, output_size, 1, totalblocks};
	if(collabo){
		dim2[2] = block_member;
	}
	
	mxArray *output1 = mxCreateNumericArray(nd, dim1, mxDOUBLE_CLASS, mxREAL);
	mxArray *output2 = mxCreateNumericArray(nd, dim2, mxDOUBLE_CLASS, mxREAL);
	
    double *top_ndata = (double *)mxGetData(output1);
	double *top_cdata = (double *)mxGetData(output2);
	double *nimg_sym =  symetrize(Srcim, search_range);
	double *cimg_sym =  symetrize(Dstim, search_range);	
    vector<vector<unsigned> > patch_table(row_ind_size * col_ind_size, vector<unsigned> (block_member, Ns*search_range+search_range));
	precompute_BM(patch_table, nimg_sym, W+2*search_range, H+2*search_range, input_size, block_member, search_range, row_ind, row_ind_size, col_ind, col_ind_size);	
		
	int *didxin = (int*)malloc(sizeof(int) * input_size * input_size);
	for (int i = 0; i < input_size * input_size; ++i){
		int di = i / input_size;
		int dj = i % input_size;
		didxin[i] = dj + di * (W + 2 * search_range);
	}
	
	int *didxo = (int*)malloc(sizeof(int) * output_size * output_size);
	for (int i = 0; i < output_size * output_size; ++i){
		int di = i / output_size + pad_size;
		int dj = i % output_size + pad_size;
		didxo[i] = dj + di * W;
	}	
	
	for (int blocknum = 0; blocknum < totalblocks; ++blocknum){
		int ind_i = blocknum / col_ind_size;
		int ind_j = blocknum % col_ind_size;
		int i_r = row_ind[ind_i];	
		int j_r = col_ind[ind_j];
		if(!collabo){
			for (int i = 0; i < output_size * output_size; ++i){
				top_cdata[ blocknum * output_size * output_size + i ] = dstdata[i_r * W + j_r + didxo[i]];
			}
		}	

		for (int c = 0; c < block_member; ++c){
			int ind = patch_table[blocknum][c];
			int d_i = ind / Ns - search_range;
			int d_j = ind % Ns - search_range;								
			for (int i = 0; i < input_size * input_size; ++i){
				top_ndata[ (blocknum * block_member + c ) * input_size * input_size + i] = 
					nimg_sym[(d_i + i_r + search_range) * (W + 2 * search_range) + d_j + j_r + search_range + didxin[i]];
			}

			if(collabo){
				for (int i = 0; i < output_size * output_size; ++i){
					top_cdata[ (blocknum * block_member + c ) * output_size * output_size + i] = 
						cimg_sym[(d_i + i_r + search_range) * (W + 2 * search_range) + d_j + j_r + search_range + didxin[i]];
				}
			}
		}
	}

	free(didxin);
	free(didxo);
	free(nimg_sym);
	free(cimg_sym);
	free(row_ind);
	free(col_ind);
	plhs[0] = output1;
	plhs[1] = output2;
}