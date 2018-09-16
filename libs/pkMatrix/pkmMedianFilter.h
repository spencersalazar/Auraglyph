/*
 *  pkmMedianFilter.h
 *  memoryMosaic
 *
 *  Created by Mr. Magoo on 7/7/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify  
 * it under the terms of the GNU General Public License as published by  
 * the Free Software Foundation, version 3.
 * 
 * This program is distributed in the hope that it will be useful, but 
 * WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
 * General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License 
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 * 
 */

#pragma once
#include "pkmMatrix.h"
#include <Accelerate/Accelerate.h>

class pkmMedianFilter
{
public:
	pkmMedianFilter(int dataLength, int filterLength)
	: mDataLength(dataLength), mFilterLength(filterLength)
	{
		frames = pkm::Mat(filterLength, dataLength, true);
		medianFrame = (float *)malloc(sizeof(float) * dataLength);
	}
	
	~pkmMedianFilter()
	{
		free(medianFrame);
	}
	
	float *getMedian(float *nextFrame)
	{
		frames.insertRowCircularly(nextFrame);
		frames.setTranspose();
		
		for (int i = 0; i < mDataLength; i++) {
			medianFrame[i] = pkm::Mat::mean(frames.row(i), mFilterLength);
		}
		
		frames.setTranspose();
		
		return medianFrame;
	}
	
	void getMedianIP(float *&nextFrame)
	{
		frames.insertRowCircularly(nextFrame);
		frames.setTranspose();
		
		for (int i = 0; i < mDataLength; i++) {
			nextFrame[i] = pkm::Mat::mean(frames.row(i), mFilterLength);
		}
		
		frames.setTranspose();
	}
	
	float *medianFrame;
	pkm::Mat frames;
	int mDataLength, mFilterLength;

};