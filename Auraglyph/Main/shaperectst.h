/*****************************************************************************************
* Copyright (c) 2006 Hewlett-Packard Development Company, L.P.
* Permission is hereby granted, free of charge, to any person obtaining a copy of 
* this software and associated documentation files (the "Software"), to deal in 
* the Software without restriction, including without limitation the rights to use, 
* copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the 
* Software, and to permit persons to whom the Software is furnished to do so, 
* subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
* INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
* PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
* HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
* CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE 
* OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
*****************************************************************************************/

/************************************************************************
 * SVN MACROS
 *
 * $LastChangedDate: 2008-07-10 15:23:21 +0530 (Thu, 10 Jul 2008) $
 * $Revision: 556 $
 * $Author: sharmnid $
 *
 ************************************************************************/

/************************************************************************
 * FILE DESCR: Header file for sample test application for Shape Recognition
 *
 * CONTENTS:
 *  main
 *
 * CHANGE HISTORY:
 * Author       Date            Description of change
 ************************************************************************/

#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif

#pragma warning(disable:4786)

#include <string>
#include "LTKInkFileReader.h"
#include "LTKLipiEngineInterface.h"
#include "LTKMacros.h"
#include "LTKInc.h"
#include "LTKTypes.h"
#include "LTKTrace.h"

#ifndef _WIN32
#define MAX_PATH 1024
#endif

/* function pointer declaration to get the function address of "createLTKLipiEngine" */
typedef LTKLipiEngineInterface* (*FN_PTR_CREATELTKLIPIENGINE) (void);
//FN_PTR_CREATELTKLIPIENGINE createLTKLipiEngine;

/* Pointer to the LipiEngine interface */
LTKLipiEngineInterface *ptrObj = NULL;

void *hLipiEngine;
int MapFunctions();



