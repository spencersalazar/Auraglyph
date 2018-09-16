// -----------------------------------------------------------------------------
//  pkmDTW.h
//  pkmMatrix
//
//  Created by Parag Mital on 10/19/12.
//  Copyright (c) 2012 Parag K Mital. All rights reserved.
//
/*
Copyright (C) 2011 Parag K. Mital

 This program is free software: you can redistribute it and/or modify  
 it under the terms of the GNU General Public License as published by  
 the Free Software Foundation, version 3.
 
 This program is distributed in the hope that it will be useful, but 
 WITHOUT ANY WARRANTY; without even the implied warranty of 
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
 General Public License for more details.
 
 You should have received a copy of the GNU General Public License 
 along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

// -----------------------------------------------------------------------------

#pragma once

#include "pkmMatrix.h"


using namespace pkm;
using namespace std;

// -----------------------------------------------------------------------------
class pkmDTW
{
public:
    // -------------------------------------------------------------------------
    pkmDTW()
    {
        bSetQuery = false;
        bHaveCandidates = false;
        bUseZNormalize = false;
        bUseCosineDistance = true;
        
        range = 1.0;

        bestSoFar = INFINITY;
    }
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    //  Change the possible range of the warping envelope
    //
    //  'r' is a floating point value within (0, 1) 
    //  This value determines how much the warping is allowed to move from the diagonal
    // -------------------------------------------------------------------------
    void setRange(float r)
    {
        range = r;
    }
    // -------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------
    //  Add elements to the database of possible candidates
    //
    //  'candidate': size is frames x dimensions
    // -------------------------------------------------------------------------
    void addToDatabase(Mat &el)
    {
        vector<float> lut_el;
        lut_el.push_back(candidates.rows);
        candidates.push_back(el);
        lut_el.push_back(candidates.rows - lut_el[0]);
        candidates_lut.push_back(lut_el);
        
        numCandidates++;
        bHaveCandidates = true;
    }
    // -------------------------------------------------------------------------
    
    
    // -------------------------------------------------------------------------
    void getNearestCandidate(const Mat &q,
                             float &distance, 
                             int &subscript, 
                             vector<int> &bestPathI,  // candidate's frame   (source)
                             vector<int> &bestPathJ)  // query's frame       (target)
    {
        if (!bHaveCandidates) {
            cout << "[ERROR::pkmDTW]: Add sequences to the database first using pkmDTW::addToDatabase(el)!" << endl;
            return;
        }
        
        // establish the query
        setQuery(q);
        
        subscript = 0;
        // search all candidates linearly
        for (int i = 0; i < numCandidates; i++)
        {
            vector<int> pathI, pathJ;
            Mat differenceMatrix, dtwDistance;
            Mat thisCandidate = candidates.rowRange(candidates_lut.row(i)[0], candidates_lut.row(i)[0] + candidates_lut.row(i)[1], false);
            
            differenceMatrix = computeDifferenceMatrix(thisCandidate);
            float thisDistance = dtw(differenceMatrix, dtwDistance, pathI, pathJ);

            if (thisDistance < bestSoFar) 
            {
                bestSoFar = thisDistance;
                bestPathI = pathI;
                bestPathJ = pathJ;
                subscript = i;
            }
        }
        distance = bestSoFar;
        bestSoFar = INFINITY;
        
        
    }
    // -------------------------------------------------------------------------
    
    
    // -------------------------------------------------------------------------
    void getNearestCandidate(float *q, int numFeatures,
                             float &distance,
                             int &subscript,
                             vector<int> &bestPathI,  // candidate's frame   (source)
                             vector<int> &bestPathJ)  // query's frame       (target)
    {
        Mat qMat(1, numFeatures, q, false);
        getNearestCandidate(qMat, distance, subscript, bestPathI, bestPathJ);
        
    }
    // -------------------------------------------------------------------------
    
    
    // -------------------------------------------------------------------------
    void getNearestCandidateEuclidean(const Mat &q,
                                      float &distance, 
                                      int &subscript) 
    {
        if (!bHaveCandidates) {
            cout << "[ERROR::pkmDTW]: Add sequences to the database first using pkmDTW::addToDatabase(el)!" << endl;
            return;
        }
        subscript = 0;
        Mat query = q;
        Mat distanceMatrix = Mat(q.rows, q.cols);
        // search all candidates linearly
        for (int i = 0; i < numCandidates; i++)
        {
            Mat thisCandidate = candidates.rowRange(candidates_lut.row(i)[0], candidates_lut.row(i)[0] + candidates_lut.row(i)[1], false);
            query.subtract(thisCandidate, distanceMatrix);
            distanceMatrix.abs();
            Mat distance2 = distanceMatrix.sum(false);
            float thisDistance = Mat::sum(distance2);
            if (thisDistance < bestSoFar) 
            {
                bestSoFar = thisDistance;
                subscript = i;
            }
        }
        distance = bestSoFar;
        bestSoFar = INFINITY;
    }
    // -------------------------------------------------------------------------
  
    
    
    // -------------------------------------------------------------------------
    void save()
    {
#ifdef WITH_OF
        candidates.save(ofToDataPath("dtw.txt"));
        candidates_lut.save(ofToDataPath("dtw_lut.txt"));
#else
        candidates.save("dtw.txt");
        candidates_lut.save("dtw_lut.txt");
#endif        
    }
    // -------------------------------------------------------------------------
       
    // -------------------------------------------------------------------------
    void load()
    {
#ifdef WITH_OF
        candidates.load(ofToDataPath("dtw.txt"));
        candidates_lut.load(ofToDataPath("dtw_lut.txt"));
#else
        candidates.load("dtw.txt");
        candidates_lut.load("dtw_lut.txt");
#endif
        
        if(bUseZNormalize)
        {
            meanValues = candidates.mean();
            stdValues = candidates.stddev();
            
            meanValues.print();
            stdValues.print();
            
            candidates.zNormalizeEachCol();
        }
        
        numCandidates = candidates_lut.rows;
        
        if (numCandidates > 0) {
            bHaveCandidates = true;
        }
    }
    // -------------------------------------------------------------------------
    
protected:
    
    // -------------------------------------------------------------------------
    // Establish the query to compare against all candidates
    //
    //  'q' is a query matrix of size T x D,
    //  T is the number of frames or time-steps
    //  D is the dimension of each data point
    // -------------------------------------------------------------------------
    void setQuery(const Mat &q)
    {
        query = q;
        if(bUseZNormalize)
        {
            for (int i = 0; i < query.rows; i++) {
                Mat thisRow = query.rowRange(i,i+1,false);
                thisRow.subtract(meanValues);
                thisRow.divide(stdValues);
            }
        }
        queryTransposed = query;
        queryTransposed.setTranspose();
        
        Mat temp = q;
        temp.sqr();
        queryNormalization = temp.sum(false);
        queryNormalization.sqrt();
        queryNormalization.setTranspose();
        
        bSetQuery = true;
    }
    // -------------------------------------------------------------------------
    
    
    // -------------------------------------------------------------------------
    // Compare stored query with the incoming matrix candidate
    // 
    //  'candidate': size is frames x dimensions
    //  'differenceMatrix': size will be candidate's rows x query's rows,
    //      i.e. differenceMatrix(i,j) indexes [1 - cosine distance of (candidate(i,:), query(j,:))]
    // -------------------------------------------------------------------------
    Mat computeDifferenceMatrix(Mat &candidate)
    {
        Mat differenceMatrix;
        if (bSetQuery) {
            if(bUseCosineDistance)
            {
                Mat temp(candidate.rows, candidate.cols);
                temp.copy(candidate);
                temp.sqr();
                Mat candidateNormalization = temp.sum(false);
                candidateNormalization.sqrt();
                Mat normalization = candidateNormalization.GEMM(queryNormalization);
                differenceMatrix = candidate.GEMM(queryTransposed);
                differenceMatrix.divide(normalization);
                
                // remove these next 3 lines for a similarity matrix instead
                float factor = -1;
                float term = 1;
                vDSP_vsmsa(differenceMatrix.data, 1, &factor, &term, differenceMatrix.data, 1, differenceMatrix.size());
            }
            else
            {
                int padding = query.rows * range;
                differenceMatrix = Mat(candidate.rows, query.rows, 1.0f);
                
                Mat ssd(1, candidate.cols);
                float size = ssd.size();
                for (int i = 0; i < candidate.rows; i++)
                {
                    Mat p1(1, candidate.cols, candidate.row(i), false);
                    for (int j = max(0, i - padding); j < std::min<int>(query.rows, i + padding - 1); j++)
                    {
                        Mat p2(1, query.cols, query.row(j), false);
                        p1.subtract(p2, ssd);
                        ssd.sqr();

                        differenceMatrix.data[query.rows*i + j] = ssd.sumAll() / size;

//                        differenceMatrix.data[query.rows*i + j] = L1Norm(candidate.row(i), query.row(j), query.cols);

                    }
                }
            }
        }
        return differenceMatrix;
    }
    // -------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------
    float dtw(Mat &differenceMatrix,
             Mat &dtwDistance,
             vector<int> &pathI,
             vector<int> &pathJ)
    {
        // calculate the dtw distance matrix
        int subscriptRange = differenceMatrix.cols * range;
        Mat traceBack(differenceMatrix.rows, differenceMatrix.cols);
        dtwDistance = differenceMatrix;
        float x, y, z;
        int i, j;
        for (i = 0; i < differenceMatrix.rows; i++) 
        {
            
            float *dist = dtwDistance.row(i);
            float *tb = traceBack.row(i);
            float minCost = 1.0;
            int k = max(0, subscriptRange - i);
//            for (j = max(0, i - subscriptRange); j < std::min<int>(i + subscriptRange - 1, differenceMatrix.cols); j++, k++)
            for (j = 0; j < differenceMatrix.cols; j++)
            {
                if (i == 0 && j == 0) {
                    *dist = *(dtwDistance.data);
                    minCost = *dist;
                    continue;
                }
                
                
                // get distance for all branches
                if ((j - 1 < 0) || (k - 1 < 0))                     x = INFINITY;                     // horizontal
                else                                                x = dtwDistance.row(i)[j-1]; 
                if ((i - 1 < 0 )|| (k + 1 > 2 * subscriptRange))    y = INFINITY;                     // veritcal
                else                                                y = dtwDistance.row(i-1)[j];      
                if ((i - 1 < 0) || (j - 1 < 0))                     z = INFINITY;                     // diagonal
                else                                                z = dtwDistance.row(i-1)[j-1];
                
                /*
                // get distance for all branches
                if (j - 1 < 0)                x = INFINITY;                     // horizontal
                else                          x = dtwDistance.row(i)[j-1]; 
                if (i - 1 < 0)                y = INFINITY;                     // veritcal
                else                          y = dtwDistance.row(i-1)[j];      
                if (i - 1 < 0 || j - 1 < 0)   z = INFINITY;                     // diagonal
                else                          z = dtwDistance.row(i-1)[j-1];
                */
                
                // find minimum branch and store path
                float val;
                if (x < y) {        // horizontal
                    val = x;
                    tb[j] = 0;
                }
                else {              // vertical
                    val = y;
                    tb[j] = 1;
                }
                if (z < val) {      // diagonal
                    val = z;
                    tb[j] = 2;
                }
                
                // aggregate distance
                dist[j] = val + dist[j];
                
                if (dist[j] < minCost) {
                    minCost = dist[j];
                }
            }
            
            // abandon early
            if (minCost > bestSoFar) {
                return INFINITY;
            }
        }
        
        // calculate path
        i--;
        j--;
        while(i >= 0 && j >= 0) 
        {
            pathI.push_back(i);
            pathJ.push_back(j);
            float t = traceBack.row(i)[j];
            if (t == 0) {                   // horizontal
                j--;
            }
            else if (t == 1) {              // vertical
                i--;
            }
            else {                          // diagonal
                i--;
                j--;
            }
        }
        return *(dtwDistance.last());
    }
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // Calculates the Sakoe-Chiba Band for a multidimensional input T x D
    //
    //  'input' is a T x D matrix (untouched, though not declared const since
    //  vDSP's max/min functions are not const) with:
    // 
    //  T frames, or time-steps
    //  D dimensions
    //
    //  [ d1 d2 .  . dn ]  t1
    //  [ .  .  .  .  . ]  t2
    //  [ .  .  .  .  . ]   .  time
    //  [ .  .  .  .  . ]   .
    //  [ .  .  .  .  . ]  tm
    //         dims
    //
    // 'upperBound' is computed as: UW_i = max(C_max(1,i-r), . . . , C_min(i+r,n)) and
    // 'lowerBound' is computed as: LW_i = min(C_max(1,i-r), . . . , C_min(i+r,n))
    // -------------------------------------------------------------------------
    void calculateBounds(Mat &input, 
                         Mat &upperBound, 
                         Mat &lowerBound);
    
    float cosineDistance(float *x, float *y, unsigned int count) {
        float dotProd, magX, magY;
        float *tmp = (float*)malloc(count * sizeof(float));
        
        vDSP_dotpr(x, 1, y, 1, &dotProd, count);
        
        vDSP_vsq(x, 1, tmp, 1, count);
        vDSP_sve(tmp, 1, &magX, count);
        magX = sqrt(magX);
        
        vDSP_vsq(y, 1, tmp, 1, count);
        vDSP_sve(tmp, 1, &magY, count);
        magY = sqrt(magY);
        
        delete tmp;
        
        return 1.0 - (dotProd / (magX * magY));
    }
    
    float L1Norm(float *buf1, float *buf2, int size)
    {
        int a = size;
        float diff = 0;
        float *p1 = buf1, *p2 = buf2;
        while (a) {
            diff += fabs(*p1++ - *p2++);
            a--;
        }
        return diff/(float)size;
    }

    
    
    
private:
    // -------------------------------------------------------------------------
    float           bestSoFar;
    float           range;
    Mat             query, queryTransposed, queryNormalization;
    
    Mat             candidates;
    Mat             candidates_lut; // idx = segment; 0 = row in candidates, 1 = num rows for segment
    Mat             meanValues, stdValues;
    int             numCandidates;
    
    Mat             queryLB;
    Mat             queryUB;
    // -------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------
    bool            bUseZNormalize, bSetQuery, bHaveCandidates, bUseCosineDistance;
    // -------------------------------------------------------------------------
};
