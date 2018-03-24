/*****************************************************************************************
* Copyright (c) 2006 Hewlett-Packard Development Company, L.P.
* Permission is hereby granted, free of charge, to any person obtaining a copy of 
* this software and associated documentation files (the "Software"), to deal in 
* the Software without restriction, including without limitation the rights to use, 
* copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the 
* Software, and to permit persons to whom the Software is furnished to do so, 
* subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included
* in all copies or substantial portions of the Software.
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
 * $LastChangedDate: 2011-02-08 16:57:52 +0530 (Tue, 08 Feb 2011) $
 * $Revision: 834 $
 * $Author: mnab $
 *
 ************************************************************************/
/************************************************************************
 * FILE DESCR: Sample test application for Shape Recognition
 *
 * CONTENTS:
 *  main
 *
 * CHANGE HISTORY:
 * Author       Date            Description of change
 ************************************************************************/

#include "shaperectst.h"
#include "LTKLoggerUtil.h"
#include "LTKErrors.h"
#include "LTKOSUtilFactory.h"
#include "LTKOSUtil.h"

char strLogFile[MAX_PATH] = "shaperectst.log";
string strLogFileName;
LTKOSUtil* utilPtr = LTKOSUtilFactory::getInstance();
extern "C" LTKLipiEngineInterface* createLTKLipiEngine();

extern "C" int shaperecst(int argc, const char** argv)
{
	const char *envstring = NULL;
	int iResult;

	//int argc = 3;
	//char* argv[] = {"shaperectst.exe", "TEST_PPP", "C:/Workspace/lipitk_release_4.0.0/projects/numerals/data/numerals_testlist.txt"};
    

	// first argument is the logical project name and the 
	// second argument is the ink file to recognize
	if(argc < 3)
	{
		cout << endl << "Usage:";
		cout << endl << "shaperectst <logicalname> <ink file to recognize>";
		cout << endl << "list of valid <logicalname>s is available in $LIPI_ROOT/projects/lipiengine.cfg file";
		cout << endl;
        delete utilPtr;
		return -1;
	}

	//Get the LIPI_ROOT environment variable 
	//envstring = getenv(LIPIROOT_ENV_STRING);
    envstring = [[[NSBundle mainBundle] resourcePath] UTF8String];
	if(envstring == NULL)
	{
		cout << endl << "Error, Environment variable is not set LIPI_ROOT" << endl;
        delete utilPtr;
		return -1;
	}

	//Load the LipiEngine.DLL
	hLipiEngine = NULL;
    iResult = utilPtr->loadSharedLib(envstring, LIPIENGINE_MODULE_STR, &hLipiEngine);

	if(iResult != SUCCESS)
	{
		cout << "Error loading LipiEngine module" << endl;
        delete utilPtr;
		return -1;
	}
	

	if(MapFunctions() != 0)
	{
		cout << "Error fetching exported functions of the module" << endl;
        delete utilPtr;
		return -1;
	}

	//create an instance of LipiEngine Module
	ptrObj = createLTKLipiEngine();

	// set the LIPI_ROOT path in Lipiengine module instance
	ptrObj->setLipiRootPath(envstring);

	//Initialize the LipiEngine module
	iResult = ptrObj->initializeLipiEngine();
	if(iResult != SUCCESS)
	{
		cout << iResult <<": Error initializing LipiEngine." << endl;

		utilPtr->unloadSharedLib(hLipiEngine);
        delete utilPtr;
        
		return -1;
	}

	//Assign the logical name of the project to this string, i.e. TAMIL_CHAR 
	//(or) "HINDI_GESTURES"
	string strLogicalName = string(argv[1]);
	LTKShapeRecognizer *pShapeReco = NULL;
	ptrObj->createShapeRecognizer(strLogicalName, &pShapeReco);
	if(pShapeReco == NULL)
	{
		cout << endl << "Error creating Shape Recognizer" << endl;

		utilPtr->unloadSharedLib(hLipiEngine);
        delete utilPtr;
		return -1;
	}

	//You can also use project and profile name to create LipiEngine instance as follows...
	//string strProjectName = "hindi_gestures";
	//string strProfileName = "default";
	//LTKShapeRecognizer *pReco = ptrObj->createShapeRecognizer(&strProjectName, &strProfileName);

	//Load the model data into memory before starting the recognition...
	iResult = pShapeReco->loadModelData();
	if(iResult != SUCCESS)
	{
		cout << endl << iResult << ": Error loading Model data." << endl;
		ptrObj->deleteShapeRecognizer(pShapeReco);

		utilPtr->unloadSharedLib(hLipiEngine);
        delete utilPtr;
        
		return -1;
	}

	//Declare variables to be used for recognition...
	LTKCaptureDevice captureDevice;
	LTKScreenContext screenContext;
	vector<int> shapeSubset; 
	int numChoices = 2;
	float confThreshold = 0.0f;
	vector<LTKShapeRecoResult> results;
	LTKTraceGroup inTraceGroup;

	// You can directly read the UNIPEN ink file which has all the 
	// device context, screen context and ink information and pass it to 
	// recognize function. Or you can create your own LTKTrace and populate
	// device and screen information as in commented code below.
	//Read the ink to be recognized from the file...
	string path(argv[2]);
    LTKInkFileReader::readUnipenInkFile(path, inTraceGroup, captureDevice, screenContext);

	// Set device context information to pass onto the recognizer
	// Uncomment and pass proper values here...
	//captureDevice.setSamplingRate(<float value>);
	//captureDevice.setXDPI(<float value>);
	//captureDevice.setYDPI(<float value>);
	//captureDevice.setLatency(<float value>);
	//captureDevice.setUniformSampling(<true or false>);

	//	Set the device context, once before starting the recognition...
	pShapeReco->setDeviceContext(captureDevice);

	results.reserve(numChoices);

	// Uncomment and edit the following lines to pass ink from the pen device 
	// to recognize function.
	// The functions should copy the values from your local ink & screen 
	// structures into inTraceGroup and screenContext variables.
	// CopyToTraceGroup(inTraceGroup, <your ink structure>);
	// CopyScreenContext(screenContext, <your screen info>);

	//now call the "recognize" method 
	iResult = pShapeReco->recognize(inTraceGroup, screenContext, shapeSubset, confThreshold, numChoices, results);
	if(iResult != SUCCESS)
	{
		cout << iResult << ": Error while recognizing." << endl;
		ptrObj->deleteShapeRecognizer(pShapeReco);

		utilPtr->unloadSharedLib(hLipiEngine);

        delete utilPtr;
		return -1;
	}

	cout << endl << "Input Logical project name = " << strLogicalName << endl;
	cout << endl << "Input ink file for recognition = " << path << endl;

	cout << endl << "Recognition Results" << endl;

	//Display the recognized results...
	for(int index =0; index < results.size(); ++index)
	{
		cout << endl << "Choice[" << index << "] " << "Recognized Shapeid = " << results[index].getShapeId() << " Confidence = " << results[index].getConfidence() << endl;
	}

	//Delete the shape recognizer object
	ptrObj->deleteShapeRecognizer(pShapeReco);

	//unload the LipiEngine module from memory...
	utilPtr->unloadSharedLib(hLipiEngine);

    delete utilPtr;

	return 0;
}

/**********************************************************************************
* NAME          : MapFunctions
* DESCRIPTION   : This method fetches the address of the exported function of
*				  lipiengine module
* ARGUMENTS     : 
* RETURNS       : 0 on success, -1 on Failure.
* NOTES         :
* CHANGE HISTROY
* Author            Date                Description of change
* 
*************************************************************************************/
int MapFunctions()
{
//	createLTKLipiEngine = NULL;
//    void* functionHandle = NULL;
//
//    int iErrorCode = utilPtr->getFunctionAddress(hLipiEngine, 
//                                             "createLTKLipiEngine", 
//                                             &functionHandle);
//
//
//    createLTKLipiEngine = (FN_PTR_CREATELTKLIPIENGINE)functionHandle;
//    
//    if(iErrorCode != SUCCESS)
//	{
//		cout << "Error mapping the createLTKLipiEngine function" << endl;
//		return -1;
//	}

	return 0;
}


