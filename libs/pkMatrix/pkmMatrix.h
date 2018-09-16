/*
 *  pkmMatrix.h
 *
 
 row-major floating point matrix utility class
 utilizes Apple Accelerate's vDSP functions for SSE optimizations
 
 Copyright (C) 2015 Parag K. Mital
 
 This program is free software: you can redistribute it and/or modify  
 it under the terms of the GNU General Public License as published by  
 the Free Software Foundation, version 3.
 
 This program is distributed in the hope that it will be useful, but 
 WITHOUT ANY WARRANTY; without even the implied warranty of 
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
 General Public License for more details.
 
 You should have received a copy of the GNU General Public License 
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 
 *
 */

#pragma once

#include <iostream>
#include <assert.h>
#include <Accelerate/Accelerate.h>
#include <vector>

#ifdef OPENCV
#define HAVE_OPENCV
#endif

#define DEBUG
//#define HAVE_OPENCV

#ifdef HAVE_OPENCV
#include <opencv2/opencv.hpp>
#endif


#ifndef EPSILON
#define EPSILON 0.0000001
#endif

#ifndef MAX
#define MAX(a,b)  ((a) < (b) ? (b) : (a))
#endif

#ifndef MIN
#define MIN(a,b)  ((a) > (b) ? (b) : (a))
#endif

// uncomment next line for vecLib optimizations
//#define MULTIPLE_OF_4(x) ((x | 0x03) + 1)
#define MULTIPLE_OF_4(x) x

template <typename T> long signum(T val) {
    return (T(0) < val) - (val < T(0));
}

namespace pkm
{
    // row-major floating point matrix
    class Mat
    {
        /////////////////////////////////////////
    public:
        // default constructor
        Mat();
        
        // destructor
        virtual ~Mat();
        
        Mat(const std::vector<float> m);
        
        Mat(const std::vector<std::vector<float> > m);
#ifdef HAVE_OPENCV
        Mat(const cv::Mat &m);
#endif
        // allocate data
        Mat(size_t r, size_t c, bool clear = false);
        
        // pass in existing data
        // non-destructive by default
        Mat(size_t r, size_t c, float *existing_buffer, bool withCopy);
        
        Mat(size_t r, size_t c, const float *existing_buffer);
        
        // set every element to a value
        Mat(size_t r, size_t c, float val);
        
        // copy-constructor, called during:
        //		pkm::Mat a(rhs);
        Mat(const Mat &rhs);
        Mat & operator=(const Mat &rhs);
        Mat & operator=(const std::vector<float> &rhs);
        Mat & operator=(const std::vector<std::vector<float> > &rhs);
#ifdef HAVE_OPENCV
        Mat & operator=(const cv::Mat &rhs);
        cv::Mat cvMat() const;
#endif
        
        inline Mat operator+(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat newMat(rows, cols);
            vDSP_vadd(data, 1, rhs.data, 1, newMat.data, 1, rows*cols);
            return newMat;
        }
        
        
        inline Mat operator+(float rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            Mat newMat(rows, cols);
            vDSP_vsadd(data, 1, &rhs, newMat.data, 1, rows*cols);
            return newMat;
        }
        
        inline Mat operator-(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat newMat(rows, cols);
            vDSP_vsub(rhs.data, 1, data, 1, newMat.data, 1, rows*cols);
            return newMat;
        }
        
        
        
        inline Mat operator-(const float scalar) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            Mat newMat(rows, cols);
            float rhs = -scalar;
            vDSP_vsadd(data, 1, &rhs, newMat.data, 1, rows*cols);
            return newMat;
        }
        
        
        inline Mat operator*(const pkm::Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(cols == rhs.rows);
#endif
            
            Mat gemmResult(rows, rhs.cols);
            //ldb must be >= MAX(N,1): ldb=30 N=3533Parameter 11 to routine cblas_sgemm was incorrect
            cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, gemmResult.rows, gemmResult.cols, cols, 1.0f, data, cols, rhs.data, rhs.cols, 0.0f, gemmResult.data, gemmResult.cols);
            //vDSP_mmul(data, 1, rhs.data, 1, gemmResult.data, 1, gemmResult.rows, gemmResult.cols, cols);
            return gemmResult;
        }
        
        
        
        inline Mat operator*(float scalar) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            
            Mat gemmResult(rows, cols);
            vDSP_vsmul(data, 1, &scalar, gemmResult.data, 1, rows*cols);
            
            return gemmResult;
        }
        
        
        inline Mat operator/(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat result(rows, cols);
            vDSP_vdiv(rhs.data, 1, data, 1, result.data, 1, rows*cols);
            return result;
        }
        
        inline Mat operator/(float scalar) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            Mat result(rows, cols);
            vDSP_vsdiv(data, 1, &scalar, result.data, 1, rows*cols);
            return result;
            
        }
        
        inline Mat operator>(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] > rhs.data[i];
            return result;
        }
        
        inline Mat operator>(float scalar) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] > scalar;
            return result;
        }
        
        inline Mat operator>=(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] >= rhs.data[i];
            return result;
        }
        
        inline Mat operator>=(float scalar) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] >= scalar;
            return result;
        }
        
        inline Mat operator<(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] < rhs.data[i];
            return result;
        }
        
        inline Mat operator<(float scalar) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] < scalar;
            return result;
        }
        
        inline Mat operator<=(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] <= rhs.data[i];
            return result;
        }
        
        inline Mat operator<=(float scalar) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] <= scalar;
            return result;
        }
        
        inline Mat operator==(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] == rhs.data[i];
            return result;
        }
        
        inline Mat operator==(float scalar) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] == scalar;
            return result;
        }
        
        inline Mat operator!=(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] != rhs.data[i];
            return result;
        }
        
        inline Mat operator!=(float scalar) const
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            Mat result(rows, cols);
            for(long i = 0; i < rows*cols; i++)
                result.data[i] = data[i] != scalar;
            return result;
        }
        
        inline float & operator[](long idx) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rows*cols >= idx);
#endif
            return data[idx];
        }
        
        // return a std::vector composed on non-zero indices of logicalMat
        inline Mat operator[](const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            std::vector<float> newMat;
            for(long i = 0; i < rows*cols; i++)
            {
                if (rhs.data[i] > 0) {
                    newMat.push_back(data[i]);
                }
            }
            if (newMat.size() > 0) {
                Mat result(1,newMat.size());
                for(long i = 0; i < newMat.size(); i++)
                {
                    result.data[i] = newMat[i];
                }
                return result;
            }
            else {
                Mat empty;
                return empty;
            }
        }
        
        
        
        friend Mat operator-(float lhs, const Mat &rhs)
        {
#ifdef DEBUG
            assert(rhs.data != NULL);
#endif
            Mat newMat(rhs.rows, rhs.cols);
            float scalar = -lhs;
            vDSP_vsadd(rhs.data, 1, &scalar, newMat.data, 1, rhs.rows*rhs.cols);
            return newMat;
        }
        
        friend Mat operator*(float lhs, const Mat &rhs)
        {
#ifdef DEBUG
            assert(rhs.data != NULL);
#endif
            
            Mat gemmResult(rhs.rows, rhs.cols);
            vDSP_vsmul(rhs.data, 1, &lhs, gemmResult.data, 1, rhs.rows*rhs.cols);
            
            return gemmResult;
        }
        friend Mat operator+(float lhs, const Mat &rhs)
        {
#ifdef DEBUG
            assert(rhs.data != NULL);
#endif
            Mat newMat(rhs.rows, rhs.cols);
            vDSP_vsadd(rhs.data, 1, &lhs, newMat.data, 1, rhs.rows*rhs.cols);
            return newMat;
        }
        
        bool isNaN()
        {
            for(long i = 0; i < rows*cols; i++)
            {
                if (isnan(data[i])) {
                    return true;
                }
            }
            return false;
        }
        
        void setNaNsTo(float f)
        {
            for(long i = 0; i < rows*cols; i++)
            {
                if (isnan(data[i]) || isinf(data[i])) {
                    data[i] = f;
                }
            }
        }
        
        // can be used to swap r and c, but without manipulating data... not sure when this would be useful
        void reshape(long r, long c)
        {
            if ((r * c) == (rows * cols))
            {
                rows = r;
                cols = c;
            }
        }
        
        // attempt to resize to new dimensions without longerpolating data, just keeping it...
        // could be more efficient to create new matrix and push_back, i haven't tested this method too much.
        void resize(size_t r, size_t c, bool clear = false)
        {
#ifdef DEBUG
            if (bUserData) {
                std::cout << "[WARNING]: Pointer to user data will be lost/leaked.  Up to user to free this memory!" << std::endl;
            }
#endif
            if (bAllocated)
            {
                
                if (r >= rows && c >= cols) {
                    
                    if (bUserData) {
                        data = (float *)malloc(MULTIPLE_OF_4(r * c) * sizeof(float));
                    }
                    else
                    {
                        float *temp_data = (float *)malloc(sizeof(float)*MULTIPLE_OF_4(rows*cols));
                        cblas_scopy(rows*cols, data, 1, temp_data, 1);
                        
                        data = (float *)realloc(data, MULTIPLE_OF_4(r * c) * sizeof(float));
                        cblas_scopy(rows*cols, temp_data, 1, data, 1);
                        
                        free(temp_data);
                        temp_data = NULL;
                    }
                    
                    if(clear)
                    {
                        vDSP_vclr(data + rows*cols, 1, r*c - rows*cols);
                    }
                    
                    rows = r;
                    cols = c;
                    
                    bAllocated = true;
                    bUserData = false;
                }
                else if(r * c == rows * cols)
                {
                    rows = r;
                    cols = c;
                }
                else {
                    printf("[ERROR: pkmMatrix::resize()] Cannot resize to a smaller matrix (yet).\n");
                }
                
                
            }
            else
            {
                data = (float *)malloc(MULTIPLE_OF_4(r * c) * sizeof(float));
                rows = r;
                cols = c;
                
                if(clear)
                {
                    vDSP_vclr(data + rows*cols, 1, r*c - rows*cols);
                }
                
                bAllocated = true;
                bUserData = false;
            }
            return;
        }
        
        // can be used to create an already declared matrix without a copy constructor
        void reset(long r, long c, bool clear = false)
        {
            //            if (!(r == rows && c == cols && !bUserData)) {
            
            rows = r;
            cols = c;
            current_row = 0;
            bCircularInsertionFull = false;
            
            releaseMemory();
            
            data = (float *)malloc(MULTIPLE_OF_4(rows * cols) * sizeof(float));
            
            bAllocated = true;
            bUserData = false;
            //            }
            
            // set every element to 0
            if(clear)
            {
                vDSP_vclr(data, 1, MULTIPLE_OF_4(rows*cols));
            }
        }
        
        // longerpolates data (row-major) to new size
        void rescale(long r, long c)
        {
            Mat longerp_mat(r, c);
            size_t old_size = rows*cols;
            size_t new_size = r*c;
            float factor = (float)std::max<size_t>(0, old_size - 1) / (float)std::max<size_t>(0, new_size - 1);
            for (long i = 0; i < new_size; i++) {
                longerp_mat[i] = factor*i;
            }
            
            float *new_data = (float *)malloc(sizeof(float) * MULTIPLE_OF_4(new_size));
            
            vDSP_vlint(data, longerp_mat.data, 1, new_data, 1, new_size, old_size);
            free(data);
            data = new_data;
            
            rows = r;
            cols = c;
        }
        
        // longerpolates data (row-major) to new size
        void rescale(long r, long c, Mat &new_mat) const
        {
            Mat longerp_mat(r, c);
            size_t old_size = rows*cols;
            size_t new_size = r*c;
            float factor = (float)std::max<size_t>(0, old_size - 1) / (float)std::max<size_t>(0, new_size - 1);
            for (float i = 0; i < new_size; i++) {
                longerp_mat[i] = factor * i;
            }
            
            new_mat = Mat(r, c);
            
            vDSP_vlint(data, longerp_mat.data, 1, new_mat.data, 1, new_size, old_size);
        }
        
        Mat max(bool row_major)
        {
            if (row_major) {
                Mat newMat(rows, 1);
                for (size_t r = 0; r < rows; r++) {
                    size_t idx = cblas_isamax(cols, data+r*cols, 1);
                    newMat.data[r] = *(data+r*cols+idx);
                }
                return newMat;
            }
            else {
                Mat newMat(1, cols);
                for (size_t c = 0; c < cols; c++) {
                    size_t idx = cblas_isamax(rows, data+c, cols)*cols;
                    newMat.data[c] = *(data+c+idx);
                }
                return newMat;
            }
        }

        
        // like rescale, but 2D information preserved..
        void longerpolate(size_t r, size_t c)
        {
            float *new_data = (float *)malloc(sizeof(float) * MULTIPLE_OF_4(r * c));
            
            vImage_Buffer src = { (void *)data, (vImagePixelCount)rows, (vImagePixelCount)cols, (size_t)(sizeof(float) * cols) };
            vImage_Buffer dest = { (void *)new_data, (vImagePixelCount)r, (vImagePixelCount)c, (size_t)(sizeof(float) * cols) };
            vImage_Error err = vImageScale_PlanarF(&src, &dest, NULL, kvImageNoFlags);
            
            if(err == kvImageNoError)
            {
                
            }
            else if (err ==  kvImageRoiLargerThanInputBuffer)
            {
                std::cout << "image roi larger than input buffer" << std::endl;
            }
            else if (err == kvImageInvalidKernelSize)
            {
                std::cout << "image invalid kernel size" << std::endl;
            }
            else if (err == kvImageInvalidEdgeStyle)
            {
                std::cout << "invalid edge style" << std::endl;
            }
            else if (err == kvImageInvalidOffset_X)
            {
                std::cout << "invalid image offset x" << std::endl;
            }
            else if (err == kvImageInvalidOffset_Y)
            {
                std::cout << "invalid image offset y" << std::endl;
            }
            else if (err == kvImageMemoryAllocationError)
            {
                std::cout << "image memory allocation error" << std::endl;
            }
            else if (err == kvImageNullPointerArgument)
            {
                std::cout << "image null pointer argument error" << std::endl;
            }
            else if (err == kvImageInvalidParameter)
            {
                std::cout << "image invalid parameter" << std::endl;
            }
            else if (err == kvImageBufferSizeMismatch)
            {
                std::cout << "image buffer size mismatch" << std::endl;
            }
            else if (err == kvImageUnknownFlagsBit)
            {
                std::cout << "unknown flag bit error" << std::endl;
            }
            
            free(data);
            data = new_data;
            
            rows = r;
            cols = c;
        }
        
        
        // like rescale, but 2D information preserved..
        void longerpolate(size_t r, size_t c, Mat &new_mat) const
        {
            new_mat.reset(r, c);
            
            vImage_Buffer src = { (void *)data, (vImagePixelCount)rows, (vImagePixelCount)cols, (size_t)sizeof(float) * cols };
            vImage_Buffer dest = { (void *)new_mat.data, (vImagePixelCount)r, (vImagePixelCount)c, (size_t)sizeof(float) * c };
            vImage_Error err = vImageScale_PlanarF(&src, &dest, NULL, kvImageNoFlags);
            
            if(err == kvImageNoError)
            {
                
            }
            else if (err ==  kvImageRoiLargerThanInputBuffer)
            {
                std::cout << "image roi larger than input buffer" << std::endl;
            }
            else if (err == kvImageInvalidKernelSize)
            {
                std::cout << "image invalid kernel size" << std::endl;
            }
            else if (err == kvImageInvalidEdgeStyle)
            {
                std::cout << "invalid edge style" << std::endl;
            }
            else if (err == kvImageInvalidOffset_X)
            {
                std::cout << "invalid image offset x" << std::endl;
            }
            else if (err == kvImageInvalidOffset_Y)
            {
                std::cout << "invalid image offset y" << std::endl;
            }
            else if (err == kvImageMemoryAllocationError)
            {
                std::cout << "image memory allocation error" << std::endl;
            }
            else if (err == kvImageNullPointerArgument)
            {
                std::cout << "image null pointer argument error" << std::endl;
            }
            else if (err == kvImageInvalidParameter)
            {
                std::cout << "image invalid parameter" << std::endl;
            }
            else if (err == kvImageBufferSizeMismatch)
            {
                std::cout << "image buffer size mismatch" << std::endl;
            }
            else if (err == kvImageUnknownFlagsBit)
            {
                std::cout << "unknown flag bit error" << std::endl;
            }
            
        }
        
        // can be used to create an already declared matrix without a copy constructor
        void reset(size_t r, size_t c, float val)
        {
            //            if (!bAllocated || r != rows || c != cols || bUserData) {
            
            rows = r;
            cols = c;
            current_row = 0;
            bCircularInsertionFull = false;
            
            releaseMemory();
            
            data = (float *)malloc(MULTIPLE_OF_4(rows * cols) * sizeof(float));
            
            bAllocated = true;
            bUserData = false;
            //            }
            
            // set every element to val
            vDSP_vfill(&val, data, 1, rows*cols);
            
        }
        
        // set every element to a value
        inline void setTo(float val)
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            vDSP_vfill(&val, data, 1, rows * cols);
        }
        
        // set every element to 0
        inline void clear()
        {
            if (rows == 0 || cols == 0) {
                return;
            }
            
            vDSP_vclr(data, 1, rows * cols);
        }
        
        /////////////////////////////////////////
        
        inline float * row(size_t r)
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            return (data + r*cols);
        }
        
        inline void insertRow(const float *buf, size_t row_idx)
        {
            float * rowData = row(row_idx);
            cblas_scopy(cols, buf, 1, rowData, 1);
        }
        
        inline bool isEmpty() const
        {
            return !(bAllocated && (rows > 0) && (cols > 0));
        }
        
        void push_back(const Mat &m)
        {
#ifdef DEBUG
            if(bUserData)
            {
                std::cout << "[WARNING]: Pointer to user data will be resized.  Possible leak!" << std::endl;
            }
#endif
            // we're not empty
            if (!isEmpty()) {
                if(!m.isEmpty())
                {
                    if (m.cols == cols){
                        // add more rows, since the columns are the same dimension
                        float *temp_data = (float *)malloc((rows+m.rows)*cols*sizeof(float));
                        
                        cblas_scopy(rows*cols, data, 1, temp_data, 1);
                        
                        cblas_scopy(m.rows*m.cols, m.data, 1, temp_data + (rows*cols), 1);
                        
                        free(data);
                        data = temp_data;
                        
                        rows+=m.rows;
                    }
                    else {
                        // the columns don't match, and there are more than 1 rows, so no idea how to push back
                        if (m.rows > 1 || rows > 1) {
                            printf("[ERROR]: pkm::Mat push_back(Mat m) requires same number of columns or both matrices with <= 1 rows to concat along columns!\n");
                            return;
                        }
                        // the columns don't match but the rows must be equal to 1 (because it is not empty)
                        else
                        {
                            // extend along column dimension
                            data = (float *)realloc(data, (cols + m.cols)*sizeof(float));
                            cblas_scopy(m.cols, m.data, 1, data + cols, 1);
                            cols += m.cols;
                        }
                    }
                }
                // so m is empty, nothing to do
                else {
                    printf("[ERROR]: pkm::Mat push_back(Mat m), matrix m is empty!\n");
                    return;
                }
            }
            else {
                *this = m;
            }
            
        }
        
        void push_back(float m)
        {
            push_back(&m, 1);
        }
        
        void push_back(const float *m, size_t size)
        {
#ifdef DEBUG
            if(bUserData)
            {
                std::cout << "[WARNING]: Pointer to user data will be resized.  Possible leak!" << std::endl;
            }
#endif
            if(size > 0)
            {
                if (bAllocated && (rows > 0) && (cols > 0)) {
                    if (size != cols) {
                        printf("[ERROR]: pkm::Mat push_back(float *m) requires same number of columns in Mat as length of std::vector!\n");
                        return;
                    }
                    data = (float *)realloc(data, MULTIPLE_OF_4((rows+1)*cols)*sizeof(float));
                    cblas_scopy(cols, m, 1, data + (rows*cols), 1);
                    rows++;
                }
                else {
                    cols = size;
                    data = (float *)malloc(sizeof(float) * MULTIPLE_OF_4(cols));
                    cblas_scopy(cols, m, 1, data, 1);
                    rows = 1;
                    bAllocated = true;
                }
            }
        }
        
        inline void push_back(const std::vector<float> &m)
        {
#ifdef DEBUG
            if(bUserData)
            {
                std::cout << "[WARNING]: Pointer to user data will be resized.  Possible leak!" << std::endl;
            }
#endif
            if (bAllocated && rows > 0 && cols > 0) {
                if (m.size() != cols) {
                    printf("[ERROR]: pkm::Mat push_back(std::vector<float> m) requires same number of columns in Mat as length of std::vector!\n");
                    return;
                }
                data = (float *)realloc(data, MULTIPLE_OF_4((rows+1)*cols)*sizeof(float));
                cblas_scopy(cols, &(m[0]), 1, data + (rows*cols), 1);
                rows++;
            }
            else {
                *this = m;
            }
            
        }
        
        inline void push_back(const std::vector<std::vector<float> > &m)
        {
#ifdef DEBUG
            if(bUserData)
            {
                std::cout << "[WARNING]: Pointer to user data will be resized.  Possible leak!" << std::endl;
            }
#endif
            if (rows > 0 && cols > 0) {
                if (m[0].size() != cols) {
                    printf("[ERROR]: pkm::Mat push_back(std::vector<std::vector<float> > m) requires same number of cols in Mat as length of each std::vector!\n");
                    return;
                }
                data = (float *)realloc(data, MULTIPLE_OF_4((rows+m.size())*cols)*sizeof(float));
                for (long i = 0; i < m.size(); i++) {
                    cblas_scopy(cols, &(m[i][0]), 1, data + ((rows+i)*cols), 1);
                }
                rows+=m.size();
            }
            else {
                *this = m;
            }
            
        }
        
        inline void insertRowCircularly(const float *buf)
        {
            insertRow(buf, current_row);
            current_row = (current_row + 1) % rows;
            if (current_row == 0) {
                bCircularInsertionFull = true;
            }
        }
        
        inline void insertRowCircularly(const std::vector<float> &m)
        {
            insertRowCircularly(&(m[0]));
        }
        
        
        inline void insertRowCircularly(const pkm::Mat &m)
        {
            insertRowCircularly(m.data);
        }
        
        float * getLastCircularRow()
        {
            unsigned long lastRow;
            if (bCircularInsertionFull) {
                lastRow = (long)(current_row - 1) >= 0 ? current_row - 1 : rows - 1;
            }
            else {
                lastRow = (long)(current_row - 1) >= 0 ? current_row - 1 : 0;
            }
            return row(lastRow);
        }
        
        inline void resetCircularRowCounter()
        {
            current_row = 0;
            bCircularInsertionFull = false;
        }
        
        bool isCircularInsertionFull()
        {
            return bCircularInsertionFull;
        }
        
        Mat getCircularAligned()
        {
            Mat aligned(rows, cols);
            if (current_row == 0) {
                cblas_scopy(size(), data, 1, aligned.data, 1);
            }
            else if(current_row < (size()-1)) {
                // first part touching end of buffer
                cblas_scopy(size()-current_row*cols, data+current_row*cols, 1, aligned.data, 1);
                // second part in the beginning of the buffer
                cblas_scopy(current_row*cols, data, 1, aligned.data+(size()-current_row*cols), 1);
            }
            else if(current_row == size()-1) {
                // second part in the beginning of the buffer
                cblas_scopy(current_row*cols, data, 1, aligned.data+(size()-current_row*cols), 1);
            }
            return aligned;
        }
        
        void alignCircularly()
        {
            if (current_row == 0) {
                return;
            }
            else {
                Mat aligned(rows, cols);
                if(current_row < (size()-1)) {
                    // first part touching end of buffer
                    cblas_scopy(size()-current_row*cols, data+current_row*cols, 1, aligned.data, 1);
                    // second part in the beginning of the buffer
                    cblas_scopy(current_row*cols, data, 1, aligned.data+(size()-current_row*cols), 1);
                }
                else if(current_row == size()-1) {
                    // second part in the beginning of the buffer
                    cblas_scopy(current_row*cols, data, 1, aligned.data+(size()-current_row*cols), 1);
                }
                cblas_scopy(size(), aligned.data, 1, data, 1);
            }
        }
        
        void removeRow(size_t i)
        {
#ifdef DEBUG
            assert(i < rows);
            assert(i >= 0);
#endif
            // are we removing the last row (or only row)?
            if(i == (rows - 1))
            {
                rows--;
                realloc(data, sizeof(float)*MULTIPLE_OF_4(rows*cols));
            }
            // we have to preserve the memory after the deleted row
            else {
                size_t numRowsToCopy = rows - i - 1;
                float *temp_data = (float *)malloc(sizeof(float)*numRowsToCopy * cols);
                cblas_scopy(numRowsToCopy * cols, row(i+1), 1, temp_data, 1);
                rows--;
                realloc(data, sizeof(float)*MULTIPLE_OF_4(rows*cols));
                cblas_scopy(cols * numRowsToCopy, temp_data, 1, row(i), 1);
                free(temp_data);
                temp_data = NULL;
            }
        }
        
        // inclusive of start, exclusive of end
        // can be a copy of the original matrix, or a way of editing the original
        // one by not copying the values (default)
        inline Mat rowRange(size_t start, size_t end, bool withCopy = true)
        {
#ifdef DEBUG
            assert(rows >= end);
            assert(end > start);
#endif
            Mat submat(end-start, cols, row(start), withCopy);
            return submat;
        }
        
        inline Mat range(size_t start, size_t end, bool withCopy = true)
        {
            Mat submat(1, end-start, row(0), withCopy);
            return submat;
        }
        
        
        inline Mat colRange(size_t start, size_t end, bool withCopy = true)
        {
#ifdef DEBUG
            assert(cols >= end);
#endif
            setTranspose();
            Mat submat(end-start, cols, row(start), withCopy);
            setTranspose();
            submat.setTranspose();
            return submat;
        }
        
        // copy data longo the matrix
        void copy(const Mat rhs)
        {
#ifdef DEBUG
            assert(rhs.rows == rows);
            assert(rhs.cols == cols);
#endif
            cblas_scopy(rows*cols, rhs.data, 1, data, 1);
            
        }
        
        void copy(const Mat &rhs, const Mat &indx)
        {
#ifdef DEBUG
            assert(indx.rows == rows);
            assert(indx.cols == cols);
#endif
            long idx = 0;
            for(long i = 0; i < rows; i++)
            {
                for(long j = 0; j < cols; j++)
                {
                    if (indx.data[i*cols + j]) {
                        data[i*cols + j] = rhs[idx];
                        idx++;
                    }
                }
                
            }
        }
        
        /////////////////////////////////////////
        
        // element-wise multiplication
        inline void multiply(const Mat &rhs, Mat &result) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(result.data != NULL);
            assert(rows == rhs.rows &&
                   rhs.rows == result.rows &&
                   cols == rhs.cols &&
                   rhs.cols == result.cols);
#endif
            vDSP_vmul(data, 1, rhs.data, 1, result.data, 1, rows*cols);
            
        }
        // element-wise multiplication
        // result stored in newly created matrix
        inline Mat multiply(const Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            Mat multiplied_matrix(rows, cols);
            
            vDSP_vmul(data, 1, rhs.data, 1, multiplied_matrix.data, 1, rows*cols);
            return multiplied_matrix;
        }
        
        inline void multiply(float scalar, Mat &result) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(result.data != NULL);
            assert(rows == result.rows &&
                   cols == result.cols);
#endif
            vDSP_vsmul(data, 1, &scalar, result.data, 1, rows*cols);
            
        }
        
        inline void multiply(float scalar)
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            vDSP_vsmul(data, 1, &scalar, data, 1, rows*cols);
        }
        
        
        
        
        inline void divide(const Mat &rhs, Mat &result) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(result.data != NULL);
            assert(rows == rhs.rows &&
                   rhs.rows == result.rows &&
                   cols == rhs.cols &&
                   rhs.cols == result.cols);
#endif
            vDSP_vdiv(rhs.data, 1, data, 1, result.data, 1, rows*cols);
            
        }
        
        inline void divide(const Mat &rhs)
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            vDSP_vdiv(rhs.data, 1, data, 1, data, 1, rows*cols);
        }
        
        inline void divide(float scalar, Mat &result) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(result.data != NULL);
            assert(rows == result.rows &&
                   cols == result.cols);
#endif
            
            vDSP_vsdiv(data, 1, &scalar, result.data, 1, rows*cols);
        }
        
        inline void divide(float scalar)
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            vDSP_vsdiv(data, 1, &scalar, data, 1, rows*cols);
        }
        
        inline void divideUnder(float scalar, Mat &result) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(result.data != NULL);
            assert(rows == result.rows &&
                   cols == result.cols);
#endif
            
            vDSP_svdiv(&scalar, data, 1, result.data, 1, rows*cols);
        }
        
        inline void divideUnder(float scalar)
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            vDSP_svdiv(&scalar, data, 1, data, 1, rows*cols);
        }
        
        inline void add(const Mat &rhs, Mat &result) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(result.data != NULL);
            assert(rows == rhs.rows &&
                   rhs.rows == result.rows &&
                   cols == rhs.cols &&
                   rhs.cols == result.cols);
#endif
            vDSP_vadd(data, 1, rhs.data, 1, result.data, 1, rows*cols);
        }
        
        inline void add(const Mat &rhs)
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            vDSP_vadd(data, 1, rhs.data, 1, data, 1, rows*cols);
        }
        
        inline void add(float scalar)
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            vDSP_vsadd(data, 1, &scalar, data, 1, rows*cols);
        }
        
        inline void subtract(const Mat &rhs, Mat &result) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(result.data != NULL);
            assert(rows == rhs.rows &&
                   rhs.rows == result.rows &&
                   cols == rhs.cols &&
                   rhs.cols == result.cols);
#endif
            vDSP_vsub(rhs.data, 1, data, 1, result.data, 1, rows*cols);
            
        }
        
        inline void clip(float negativeClipAmt, float positiveClipAmt)
        {
            vDSP_vclip(data, 1, &negativeClipAmt, &positiveClipAmt, data, 1, rows*cols);
        }
        
        inline void subtract(const Mat &rhs)
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(rows == rhs.rows &&
                   cols == rhs.cols);
#endif
            vDSP_vsub(rhs.data, 1, data, 1, data, 1, rows*cols);
        }
        
        inline void subtract(float scalar)
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            float rhs = -scalar;
            vDSP_vsadd(data, 1, &rhs, data, 1, rows*cols);
        }
        
        inline void dot(const Mat &rhs, Mat &result) const
        {
            GEMM(rhs, result);
        }
        
        inline void GEMM(const Mat &rhs, Mat &result) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(result.data != NULL);
            assert(rows == result.rows &&
                   rhs.cols == result.cols &&
                   cols == rhs.rows);
#endif
            
            cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, result.rows, result.cols, cols, 1.0f, data, cols, rhs.data, rhs.cols, 0.0f, result.data, result.cols);
            //vDSP_mmul(data, 1, rhs.data, 1, result.data, 1, result.rows, result.cols, cols);
            
        }
        
        inline Mat dot(const pkm::Mat &rhs) const
        {
            return GEMM(rhs);
        }
        
        inline Mat GEMM(const pkm::Mat &rhs) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rhs.data != NULL);
            assert(cols == rhs.rows);
#endif
            
            Mat gemmResult(rows, rhs.cols);
            
            //printf("lda: %d\nldb: %d\nldc: %d\n", rows, rhs.rows, gemmResult.rows);
            cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, gemmResult.rows, gemmResult.cols, cols, 1.0f, data, cols, rhs.data, rhs.cols, 0.0f, gemmResult.data, gemmResult.cols);
            //vDSP_mmul(data, 1, rhs.data, 1, gemmResult.data, 1, gemmResult.rows, gemmResult.cols, cols);
            return gemmResult;
            
        }
        
        inline void setTranspose()
        {
#ifdef DEBUG
            assert(data != NULL);
            if (bUserData) {
                print("[Warning]: Transposing user data!");
            }
#endif
            if (rows == 1 || cols == 1) {
                
                size_t tempvar = cols;
                cols = rows;
                rows = tempvar;
            }
            else {
                float *temp_data = (float *)malloc(sizeof(float)*rows*cols);
                vDSP_mtrans(data, 1, temp_data, 1, cols, rows);
                cblas_scopy(rows*cols, temp_data, 1, data, 1);
                free(temp_data);
                temp_data = NULL;
                size_t tempvar = cols;
                cols = rows;
                rows = tempvar;
            }
        }
        
        Mat getTranspose() const;
        
        
        // diagonalize the std::vector longo a square matrix with
        // the current data std::vector along the diagonal
        inline void setDiagMat()
        {
#ifdef DEBUG
            assert(data != NULL);
            if(bUserData)
            {
                std::cout << "[WARNING] Pointer to user data will be resized and therefore possibly lost/leaked.  Up to the user to free this memory!" << std::endl;
            }
#endif
            if((rows == 1 && cols > 1) || (cols == 1 && rows > 1))
            {
                
                size_t diagonal_elements = std::max<size_t>(rows,cols);
                
                // create a square matrix
                float *temp_data = (float *)malloc(diagonal_elements*diagonal_elements*sizeof(float));
                
                // set values to 0
                vDSP_vclr(temp_data, 1, diagonal_elements*diagonal_elements);
                
                // set diagonal elements to the current std::vector in data
                for (size_t i = 0; i < diagonal_elements; i++) {
                    temp_data[i*diagonal_elements+i] = data[i];
                }
                
                // store in data
                rows = cols = diagonal_elements;
                std::swap(data, temp_data);
                
                if(!bUserData)
                {
                    free(temp_data);
                    temp_data = NULL;
                }
            }
            
        }
        Mat getDiag() const;
        Mat getDiagMat() const;
        
        void flatten(bool row_major = true)
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            if(row_major)
            {
                cols = rows * cols;
                rows = rows > 0 ? 1 : 0;
            }
            else
            {
                rows = rows * cols;
                cols = cols > 0 ? 1 : 0;
            }
        }
        
        void abs();
        
        // returns a new matrix with each el the abs(el)
        static Mat abs(const Mat &A);
        
        /*
         // returns a new matrix with each el the log(el)
         static Mat log(Mat &A);
         
         // returns a new matrix with each el the exp(el)
         static Mat exp(Mat &A);
         */
        
        // returns a new diagonalized matrix version of A
        //        static Mat diag(const Mat &A);
        static Mat diagMat(const Mat &A);
        
        // get a new identity matrix of size dim x dim
        static Mat identity(size_t dim);
        
        // get a new identity matrix of size dim x dim
        static Mat eye(size_t dim);
        
        static Mat zeros(size_t rows, size_t cols)
        {
            return Mat(rows, cols, true);
        }
        
        // set every element to a random value between low and high
        void setRand(float low = 0.0, float high = 1.0);
        
        // create a random matrix
        static Mat rand(size_t r, size_t c, float low = 0.0, float high = 1.0);
        
        // sum across rows or columns creating a std::vector from a matrix, or a scalar from a std::vector
        Mat sum(bool across_rows = true);
        
        // repeat a std::vector for size times
        static Mat repeat(const Mat &m, size_t size)
        {
            // repeat a column std::vector across cols
            if(m.rows > 1 && m.cols == 1 && size > 1)
            {
                Mat repeated_matrix(size, m.rows);
                for (size_t i = 0; i < size; i++) {
                    cblas_scopy(m.rows, m.data, 1, repeated_matrix.data + (i*m.rows), 1);
                }
                repeated_matrix.setTranspose();
                return repeated_matrix;
            }
            else if( m.rows == 1 && m.cols > 1 && size > 1)
            {
                Mat repeated_matrix(size, m.cols, 5.0f);
                
                for (size_t i = 0; i < size; i++) {
                    cblas_scopy(m.cols, m.data, 1, repeated_matrix.data + (i*m.cols), 1);
                }
                return repeated_matrix;
            }
            else {
                printf("[ERROR]: repeat requires a std::vector and a size to repeat on.");
                Mat a;
                return a;
            }
            
        }
        
        // repeat a std::vector for size times
        static void repeat(Mat &dst, const Mat &m, size_t size)
        {
            // repeat a column std::vector across cols
            if(m.rows > 1 && m.cols == 1 && size > 1)
            {
                dst.reset(size, m.rows);
                for (size_t i = 0; i < size; i++) {
                    cblas_scopy(m.rows, m.data, 1, dst.data + (i*m.rows), 1);
                }
                dst.setTranspose();
            }
            else if( m.rows == 1 && m.cols > 1 && size > 1)
            {
                dst.reset(size, m.cols);
                
                for (size_t i = 0; i < size; i++) {
                    cblas_scopy(m.cols, m.data, 1, dst.data + (i*m.cols), 1);
                }
            }
            else {
                printf("[ERROR]: repeat requires a std::vector and a size to repeat on.");
                
            }
            
        }
        
        static float meanMagnitude(const float *buf, size_t size)
        {
            float mean;
            vDSP_meamgv(buf, 1, &mean, size);
            return mean;
        }
        
        
        static float l1norm(const float *buf1, const float *buf2, size_t size)
        {
            size_t a = size;
            float diff = 0;
            const float *p1 = buf1, *p2 = buf2;
            while (a) {
                diff += fabs(*p1++ - *p2++);
                a--;
            }
            return diff;///(float)size;
        }
        
        static float sumOfAbsoluteDifferences(const float *buf1, const float *buf2, size_t size)
        {
            size_t a = size;
            float diff = 0;
            const float *p1 = buf1, *p2 = buf2;
            while (a) {
                diff += fabs(*p1++ - *p2++);
                a--;
            }
            return diff/(float)size;
        }
        
        static float mean(const float *buf, size_t size, size_t stride = 1)
        {
            float val;
            vDSP_meanv(buf, stride, &val, size);
            return val;
        }
        
        static float mean(const Mat &m, size_t stride = 1)
        {
            float val;
            vDSP_meanv(m.data, stride, &val, m.rows * m.cols);
            return val;
        }
        
        static float var(const float *buf, size_t size, size_t stride = 1)
        {
            float m = mean(buf, size, stride);
            float v = 0;
            float sqr = 0;
            const float *p = buf;
            size_t a = size;
            while (a) {
                sqr = (*p - m);
                p += stride;
                v += sqr*sqr;
                a--;
            }
            return v/(float)size;
        }
        
        static float stddev(const float *buf, size_t size, size_t stride = 1)
        {
            float m = mean(buf, size, stride);
            float v = 0;
            float sqr = 0;
            const float *p = buf;
            size_t a = size;
            while (a) {
                sqr = (*p - m);
                p += stride;
                v += sqr*sqr;
                a--;
            }
            return sqrtf(v/(float)size);
        }
        
        float rms()
        {
            float val;
            vDSP_rmsqv(data, 1, &val, rows*cols);
            return val;
        }
        
        static float rms(const float *buf, long size)
        {
            float val;
            vDSP_rmsqv(buf, 1, &val, size);
            return val;
        }
        
        static float min(const Mat &A)
        {
            float minval;
            vDSP_minv(A.data, 1, &minval, A.rows*A.cols);
            return minval;
        }
        
        static unsigned long minIndex(const Mat &A)
        {
            float minval;
            unsigned long minidx;
            vDSP_minvi(A.data, 1, &minval, &minidx, A.rows*A.cols);
            return minidx;
        }
        
        void min(float &val, unsigned long &idx) const
        {
            vDSP_minvi(data, 1, &val, &idx, rows*cols);
        }
        
        static float max(const Mat &A)
        {
            float maxval;
            vDSP_maxv(A.data, 1, &maxval, A.rows*A.cols);
            return maxval;
        }
        
        unsigned long maxIndex()
        {
            float maxval;
            unsigned long maxidx;
            vDSP_maxvi(data, 1, &maxval, &maxidx, rows*cols);
            return maxidx;
        }
        
        static unsigned long maxIndex(const Mat &A)
        {
            float maxval;
            unsigned long maxidx;
            vDSP_maxvi(A.data, 1, &maxval, &maxidx, A.rows*A.cols);
            return maxidx;
        }
        
        void max(float &val, unsigned long &idx)
        {
            vDSP_maxvi(data, 1, &val, &idx, rows*cols);
        }
        
        float sumAll()
        {
            float sumval;
            vDSP_sve(data, 1, &sumval, rows*cols);
            return sumval;
        }
        
        static float sum(const Mat &A)
        {
            float sumval;
            vDSP_sve(A.data, 1, &sumval, A.rows*A.cols);
            return sumval;
        }
        
        Mat var(bool row_major = true) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rows >0 &&
                   cols >0);
#endif
            if (row_major) {
                if (rows == 1) {
                    return *this;
                }
                Mat newMat(1, cols);
                
                for(long i = 0; i < cols; i++)
                {
                    newMat.data[i] = var(data + i, rows, cols);
                }
                return newMat;
            }
            else {
                if (cols == 1) {
                    return *this;
                }
                Mat newMat(rows, 1);
                for(long i = 0; i < rows; i++)
                {
                    newMat.data[i] = var(data + i*cols, cols, 1);
                }
                return newMat;
            }
        }
        
        Mat stddev(bool row_major = true) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rows >0 &&
                   cols >0);
#endif
            if (row_major) {
                if (rows == 1) {
                    return *this;
                }
                Mat newMat(1, cols);
                
                for(size_t i = 0; i < cols; i++)
                {
                    newMat.data[i] = stddev(data + i, rows, cols);
                }
                return newMat;
            }
            else {
                if (cols == 1) {
                    return *this;
                }
                Mat newMat(rows, 1);
                for(size_t i = 0; i < rows; i++)
                {
                    newMat.data[i] = stddev(data + i*cols, cols, 1);
                }
                return newMat;
            }
        }
        
        
        Mat mean(bool row_major = true) const
        {
#ifdef DEBUG
            assert(data != NULL);
            assert(rows >0 &&
                   cols >0);
#endif
            if (row_major) {
                
                if (rows == 1) {
                    Mat newMat(1, cols, data, true);
                    return newMat;
                }
                Mat newMat(1, cols);
                
                for(size_t i = 0; i < cols; i++)
                {
                    newMat.data[i] = mean(data + i, rows, cols);
                }
                return newMat;
            }
            else {
                if (cols == 1) {
                    return *this;
                }
                Mat newMat(rows, 1);
                for(size_t i = 0; i < rows; i++)
                {
                    newMat.data[i] = mean(data + i*cols, cols, 1);
                }
                return newMat;
            }
            
        }
        
        inline void zNormalize()
        {
            float mean, stddev;
            size_t size = rows * cols;
            getMeanAndStdDev(mean, stddev);
            
            // subtract mean
            float rhs = -mean;
            vDSP_vsadd(data, 1, &rhs, data, 1, size);
            
            // divide by std dev
            vDSP_vsdiv(data, 1, &stddev, data, 1, size);
        }
        
        inline void zNormalizeEachCol()
        {
            float mean, stddev;
            float sumval, sumsquareval;
            size_t size = rows;
            if (size > 1) {
                for (size_t i = 0; i < cols; i++) {
                    vDSP_sve(data + i, cols, &sumval, size);
                    vDSP_svesq(data + i, cols, &sumsquareval, size);
                    mean = sumval / (float) size;
                    stddev = sqrtf( sumsquareval / (float) size - mean * mean) + EPSILON;
                    
                    // subtract mean
                    float rhs = -mean;
                    vDSP_vsadd(data + i, cols, &rhs, data + i, cols, size);
                    
                    // divide by std dev
                    vDSP_vsdiv(data + i, cols, &stddev, data + i, cols, size);
                }
            }
        }
        
        inline void centerEachCol()
        {
            float mean;
            float sumval;
            size_t size = rows;
            if (size > 1) {
                for (size_t i = 0; i < cols; i++) {
                    vDSP_sve(data + i, cols, &sumval, size);
                    mean = sumval / (float) size;
                    
                    // subtract mean
                    float rhs = -mean;
                    vDSP_vsadd(data + i, cols, &rhs, data + i, cols, size);
                }
            }
        }
        
        
        inline void getMeanAndStdDev(Mat &meanMat, Mat &stddevMat) const
        {
            meanMat.reset(1, cols);
            stddevMat.reset(1, cols);
            
            float mean, stddev;
            float sumval, sumsquareval;
            size_t size = rows;
            if (size == 1) {
                cblas_scopy(cols, data, 1, meanMat.data, 1);
                stddevMat.setTo(1.0);
            }
            else if (size > 1) {
                for (size_t i = 0; i < cols; i++) {
                    vDSP_sve(data + i, cols, &sumval, size);
                    vDSP_svesq(data + i, cols, &sumsquareval, size);
                    mean = sumval / (float) size;
                    stddev = sqrtf( sumsquareval / (float) size - mean * mean);
                    
                    meanMat[i] = mean;
                    stddevMat[i] = stddev;
                }
            }
        }
        
        
        inline void getMeanAndStdDev(float &mean, float &stddev) const
        {
            float sumval, sumsquareval;
            size_t size = rows * cols;
            vDSP_sve(data, 1, &sumval, size);
            vDSP_svesq(data, 1, &sumsquareval, size);
            mean = sumval / (float) size;
            stddev = sqrtf( sumsquareval / (float) size - mean * mean);
        }
        
        // rescale the values in each row to their maximum
        void setNormalize(bool row_major = true);
        
        void normalizeRow(size_t r)
        {
            float min, max;
            vDSP_minv(&(data[r*cols]), 1, &min, cols);
            vDSP_maxv(&(data[r*cols]), 1, &max, cols);
            float height = max-min;
            min = -min;
            vDSP_vsadd(&(data[r*cols]), 1, &min, &(data[r*cols]), 1, cols);
            if (height != 0) {
                vDSP_vsdiv(&(data[r*cols]), 1, &height, &(data[r*cols]), 1, cols);
            }
        }
        
        void divideEachVecByMaxVecElement(bool row_major);
        void divideEachVecBySum(bool row_major);
        
        void solve()
        {
            
        }
        
        void inv2x2()
        {
#ifdef DEBUG
            assert(rows == 2);
            assert(cols == 2);
#endif
            float det = 1.0 / (data[0]*data[3] - data[2]*data[1]);
            float a = data[0];
            float b = data[1];
            float c = data[2];
            float d = data[3];
            data[0] = d * det;
            data[1] = -b * det;
            data[2] = -c * det;
            data[3] = a * det;
        }
        
        
        void inv()
        {
#ifdef DEBUG
            assert(rows == cols);
#endif
            if (rows == 1 && cols == 1) {
                data[0] = 1.0 / data[0];
            }
            else if(rows == 2 && cols == 2) {
                inv2x2();
            }
            else {
                
                __CLPK_integer n = rows;
                __CLPK_integer info = 0;
                __CLPK_integer ipiv[rows];
                __CLPK_real workspace[n];
                
                sgetrf_(&n, &n, data, &n, ipiv, &info);
    #ifdef DEBUG
                if (info != 0)
                {
                    printf("[pkmMatrix]: ERROR: Something went wrong factoring A\n");
                    return;
                }
    #endif
                
                sgetri_(&n, data, &n, ipiv, workspace, &n, &info);
    #ifdef DEBUG
                if (info != 0) {
                    printf("[pkmMatrix]: ERROR: Something went wrong w/ inverse A\n");
                }
    #endif
            }
            
        }
        
        Mat getInv() const
        {
            
#ifdef DEBUG
            assert(rows == cols);
#endif
            Mat m(rows, cols, 0.0f);
            memcpy(m.data, data, sizeof(float)*rows*cols);
            
            if (rows == 1 && cols == 1) {
                m[0] = 1.0 / m[0];
                return m;
            }
            else if (rows == 2 && cols == 2) {
                m.inv2x2();
                return m;
            }
            else {
                
                __CLPK_integer n = rows;
                __CLPK_integer info = 0;
                __CLPK_integer ipiv[rows];
                __CLPK_real workspace[n];
                
                sgetrf_(&n, &n, m.data, &n, ipiv, &info);
    #ifdef DEBUG
                if (info != 0)
                {
                    printf("[pkmMatrix]: ERROR: Something went wrong LU factorization A\n");
                }
    #endif
                sgetri_(&n, m.data, &n, ipiv, workspace, &n, &info);
                
    #ifdef DEBUG
                if (info != 0) {
                    printf("[pkmMatrix]: ERROR: Something went wrong w/ inverse A\n");
                }
    #endif
                
                return m;
            }
        }
        
        
        // input is 1 x d dimensional std::vector
        // mean is 1 x d dimensional std::vector
        // sigma is d x d dimensional matrix
        static float gaussianPosterior(const Mat &input, Mat mean, Mat sigma)
        {
#ifdef DEBUG
            assert(input.cols == mean.cols);
            assert(input.cols == sigma.rows);
            assert(input.cols == sigma.cols);
#endif
            float A = 1.0 / (powf(M_PI * 2.0, input.cols / 2.0) * sqrtf(sigma[0]*sigma[3] - sigma[2]*sigma[1]));
            Mat inputCopy = input;
            inputCopy.subtract(mean);
            sigma.inv2x2();
            Mat a = inputCopy.GEMM(sigma);
            Mat l = inputCopy;
            l.setTranspose();
            Mat b = a.GEMM(l);
            return (A * expf(-0.5 * b[0]));
        }
        
        void sqr()
        {
            vDSP_vmul(data, 1, data, 1, data, 1, rows*cols);
        }
        
        static Mat sqr(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            vDSP_vmul(b.data, 1, b.data, 1, newMat.data, 1, b.rows*b.cols);
            return newMat;
        }
        
        pkm::Mat& sqrt()
        {
            int size = rows*cols;
            vvsqrtf(data, data, &size);
            return *this;
        }
        
        static Mat sqrt(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            int size = b.rows*b.cols;
            vvsqrtf(newMat.data, b.data, &size);
            return newMat;
        }
        
        void sin()
        {
            int size = rows*cols;
            vvsinf(data, data, &size);
        }
        
        static Mat sin(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            int size = b.rows*b.cols;
            vvsinf(newMat.data, b.data, &size);
            return newMat;
        }
        
        void cos()
        {
            int size = rows*cols;
            vvcosf(data, data, &size);
        }
        
        static Mat cos(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            int size = b.rows*b.cols;
            vvcosf(newMat.data, b.data, &size);
            return newMat;
        }
        
        void pow(float p)
        {
            int size = rows*cols;
            vvpowf(data, &p, data, &size);
        }
        
        static Mat pow(const Mat &b, float p)
        {
            Mat newMat(b.rows, b.cols);
            int size = b.rows*b.cols;
            vvpowf(newMat.data, &p, b.data, &size);
            return newMat;
        }
        
        void log()
        {
            int size = rows*cols;
            vvlogf(data, data, &size);
        }
        
        static Mat log(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            int size = b.rows*b.cols;
            vvlogf(newMat.data, b.data, &size);
            return newMat;
        }
        
        void log10()
        {
            int size = rows*cols;
            vvlog10f(data, data, &size);
        }
        
        static Mat log10(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            int size = b.rows*b.cols;
            vvlog10f(newMat.data, b.data, &size);
            return newMat;
        }
        
        void exp()
        {
            int size = rows*cols;
            vvexpf(data, data, &size);
        }
        
        static Mat exp(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            int size = b.rows*b.cols;
            vvexpf(newMat.data, b.data, &size);
            return newMat;
        }
        
        void floor()
        {
            int size = rows*cols;
            vvfloorf(data, data, &size);
        }
        
        static Mat floor(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            int size = b.rows*b.cols;
            vvfloorf(newMat.data, b.data, &size);
            return newMat;
        }
        
        void ceil()
        {
            int size = rows*cols;
            vvceilf(data, data, &size);
        }
        
        static Mat ceil(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            int size = b.rows*b.cols;
            vvceilf(newMat.data, b.data, &size);
            return newMat;
        }
        
        static Mat sgn(const Mat &b)
        {
            Mat newMat(b.rows, b.cols);
            float *p = b.data;
            float *p2 = newMat.data;
            for (long i = 0; i < b.rows*b.cols; i++) {
                *p2++ = signum<float>(*p++);
            }
            return newMat;
        }
        
        static Mat resize(const Mat &a, long newSize)
        {
            long originalSize = a.size();
            Mat b(1, newSize);
            float factor = (float)((newSize - 1) / (float)(originalSize-1));
            for (long i = 0; i < newSize; i++) {
                b[i] = i / factor;
            }
            Mat c(1, newSize);
            vDSP_vlint(a.data, b.data, 1, c.data, 1, newSize, originalSize);
            return c;
        }
        
        inline long size() const
        {
            return rows * cols;
        }
        
        inline float *last()
        {
#ifdef DEBUG
            assert(data != NULL);
#endif
            return data + (rows * cols - 1);
        }
        
        inline float *first()
        {
#ifdef DEBUG
            assert(data != NULL);
#endif	
            return data;
        }
        
        void getIndexOfClosestRowL1(const pkm::Mat& row_vector, float &best_sum, size_t &best_idx)
        {
            best_sum = HUGE_VALF;
            best_idx = 0;
            pkm::Mat sub(1, cols);
            for( size_t i = 0; i < rows; i++ )
            {
                rowRange(i, i+1, false).subtract(row_vector, sub);
                sub.abs();
                float l1 = sub.sum().sum(false)[0];
                if (l1 < best_sum) {
                    best_sum = l1;
                    best_idx = i;
                }
            }
        }
        
        
        void getIndexOfClosestRowL2(const pkm::Mat& row_vector, float &best_sum, size_t &best_idx)
        {
            best_sum = HUGE_VALF;
            best_idx = 0;
            pkm::Mat sub(1, cols);
            for( size_t i = 0; i < rows; i++ )
            {
                rowRange(i, i+1, false).subtract(row_vector, sub);
                sub.sqr();
                float l1 = sub.sum().sum(false)[0];
                if (l1 < best_sum) {
                    best_sum = l1;
                    best_idx = i;
                }
            }
        }
        
        void getIndexOfClosestRowL2(const pkm::Mat& row_vector, float &best_sum, size_t &best_idx, float &average_sum)
        {
            average_sum = 0;
            best_sum = HUGE_VALF;
            best_idx = 0;
            pkm::Mat sub(1, cols);
            for( size_t i = 0; i < rows; i++ )
            {
                rowRange(i, i+1, false).subtract(row_vector, sub);
                sub.sqr();
                float l1 = sub.sum().sum(false)[0];
                average_sum += l1;
                if (l1 < best_sum) {
                    best_sum = l1;
                    best_idx = i;
                }
            }
            average_sum /= (float)rows;
        }
        
        inline long svd(Mat &U, Mat &S, Mat &V_t)
        {
            //            print();
            
            __CLPK_integer m = rows;
            __CLPK_integer n = cols;
            
            __CLPK_integer lda = m;
            __CLPK_integer ldu = m;
            __CLPK_integer ldv = n;
            
            size_t nSVs = m > n ? n : m;
            
            U.reset(m, m);
            V_t.reset(n, n);
            S.reset(1, nSVs);
            
            float workSize;
            
            __CLPK_integer lwork = -1;
            __CLPK_integer info = 0;
            
            // iwork dimension should be at least 8*min(m,n)
            __CLPK_integer iwork[8*nSVs];
            
            //https://groups.google.com/forum/#!topic/julia-dev/mmgO65i6-fA sdd (divide/conquer, better if memory is available, for large matrices) versus svd (qr)
            //http://docs.oracle.com/cd/E19422-01/819-3691/dgesvd.html
            
            // call svd to query optimal work size:
            char job = 'A';
            sgesdd_(&job, &m, &n, data, &lda, S.data, U.data, &ldu, V_t.data, &ldv, &workSize, &lwork, iwork, &info);
            
            lwork = (long)workSize;
            float work[lwork];
            
            // actual svd
            sgesdd_(&job, &m, &n, data, &lda, S.data, U.data, &ldu, V_t.data, &ldv, work, &lwork, iwork, &info);
            
            // Check for convergence
            if( info > 0 ) {
                printf( "[pkm::Mat]::svd(...) sgesvd_() failed to converge.\\n" );
            }
            
            return info;
            
        }
        
        void copyToDouble(double *ptr) const
        {
            vDSP_vspdp(data, 1, ptr, 1, rows*cols);
        }
        
        
        void copyFromDouble(const double *ptr, size_t rows, size_t cols)
        {
            resize(rows, cols);
            vDSP_vdpsp(ptr, 1, data, 1, size());
        }
        
        bool save(std::string filename)
        {
            FILE *fp;
            fp = fopen(filename.c_str(), "w");
            if(fp)
            {
                fprintf(fp, "%lu %lu\n", rows, cols);
                for(long i = 0; i < rows; i++)
                {
                    for(long j = 0; j < cols; j++)
                    {
                        fprintf(fp, "%f, ", data[i*cols + j]);
                    }
                    fprintf(fp,"\n");
                }
                fclose(fp);
                return true;
            }
            else
            {
                return false;
            }
        }
        
        bool saveCSV(std::string filename)
        {
            FILE *fp;
            fp = fopen(filename.c_str(), "w");
            if(fp)
            {
                //                fprintf(fp, "%d %d\n", rows, cols);
                for(long i = 0; i < rows; i++)
                {
                    for(long j = 0; j < cols; j++)
                    {
                        fprintf(fp, "%f, ", data[i*cols + j]);
                    }
                    fprintf(fp,"\n");
                }
                fclose(fp);
                return true;
            }
            else
            {
                return false;
            }
        }
        
        bool load(std::string filename)
        {
            if (bAllocated && !bUserData) {
                free(data); data = NULL;
                rows = cols = 0;
            }
            FILE *fp;
            fp = fopen(filename.c_str(), "r");
            if (fp) {
                fscanf(fp, "%lu %lu\n", &rows, &cols);
                data = (float *)malloc(sizeof(float) * MULTIPLE_OF_4(rows * cols));
                for(long i = 0; i < rows; i++)
                {
                    for(long j = 0; j < cols; j++)
                    {
                        fscanf(fp, "%f, ", &(data[i*cols + j]));
                    }
                    fscanf(fp, "\n");
                }
                fclose(fp);
                bAllocated = true;
                return true;
            }
            else {
                return false;
            }
        }
        
        bool load(std::string filename, long r, long c)
        {
            if (bAllocated && !bUserData) {
                free(data); data = NULL;
                rows = cols = 0;
            }
            FILE *fp;
            fp = fopen(filename.c_str(), "r");
            if (fp) {
                rows = r;
                cols = c;
                data = (float *)malloc(sizeof(float) * MULTIPLE_OF_4(rows * cols));
                for(long i = 0; i < rows; i++)
                {
                    for(long j = 0; j < cols; j++)
                    {
                        fscanf(fp, "%f, ", &(data[i*cols + j]));
                    }
                    fscanf(fp, "\n");
                }
                fclose(fp);
                bAllocated = true;
                return true;
            }
            else {
                return false;
            }
        }
        
        // simple print output (be careful with large matrices!)
        void print(bool row_major = true, char delimiter = ',');
        // only prints maximum of 5 rows/cols
        void printAbbrev(bool row_major = true, char delimiter = ',');
        
        
        
        /////////////////////////////////////////
        
        size_t current_row;	// for circular insertion
        bool bCircularInsertionFull;
        size_t rows;
        size_t cols;
        
        float *data;
        
        bool bAllocated = false;
        bool bUserData;
        
        
    protected:
        void releaseMemory()
        {
            if(bAllocated)
            {
                if (!bUserData) {
                    assert(data != NULL);
                    free(data);
                    data = NULL;
                    bAllocated = false;
                }
            }
        }
    };
};