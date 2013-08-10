//
//  AGHandwritingRecognizer.m
//  Auragraph
//
//  Created by Spencer Salazar on 8/9/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGHandwritingRecognizer.h"

#include "LTKLipiEngineInterface.h"
#include "LTKMacros.h"
#include "LTKInc.h"
#include "LTKTypes.h"
#include "LTKTrace.h"
#include "LTKLoggerUtil.h"
#include "LTKErrors.h"
#include "LTKOSUtilFactory.h"
#include "LTKOSUtil.h"


extern "C" LTKLipiEngineInterface* createLTKLipiEngine();


static AGHandwritingRecognizerFigure g_figureForNumeralShape[] =
{
    AG_FIGURE_0,
    AG_FIGURE_1,
    AG_FIGURE_2,
    AG_FIGURE_3,
    AG_FIGURE_4,
    AG_FIGURE_5,
    AG_FIGURE_6,
    AG_FIGURE_7,
    AG_FIGURE_8,
    AG_FIGURE_9,
};

static AGHandwritingRecognizerFigure g_figureForShape[] =
{
    AG_FIGURE_CIRCLE,
    AG_FIGURE_SQUARE,
    AG_FIGURE_TRIANGLE_UP,
    AG_FIGURE_TRIANGLE_DOWN,
};


@interface AGHandwritingRecognizer ()
{
    LTKOSUtil* _util;
    LTKLipiEngineInterface *_engine;
    LTKShapeRecognizer * _numeralReco;
    LTKShapeRecognizer * _shapeReco;
}

@end


@implementation AGHandwritingRecognizer

- (id)init
{
    if(self = [super init])
    {
        int iResult;
        
        // get util object
        _util = LTKOSUtilFactory::getInstance();
        
        // create engine
        _engine = createLTKLipiEngine();
        
        // set root path for projects
        _engine->setLipiRootPath([[[NSBundle mainBundle] resourcePath] UTF8String]);
        
        // initialize
        iResult = _engine->initializeLipiEngine();
        if(iResult != SUCCESS)
        {
            cout << iResult <<": Error initializing LipiEngine." << endl;
            delete _util;
            _util = NULL;
            
            return nil;
        }
        
        // configure capture device settings
        LTKCaptureDevice captureDevice;
        // hopefully none of these values are important
        captureDevice.setSamplingRate(60); // guesstimate
        captureDevice.setXDPI(132); // basic ipad DPI
        captureDevice.setYDPI(132); // basic ipad DPI
        captureDevice.setLatency(0.01); // ballpark guess, is probably higher
        captureDevice.setUniformSampling(false);
        
        /* create shape recognizer */
        _shapeReco = NULL;
        string recoName = "SHAPEREC_SHAPES";
        _engine->createShapeRecognizer(recoName, &_shapeReco);
        if(_shapeReco == NULL)
        {
            cout << endl << "Error creating Shape Recognizer" << endl;
            delete _util;
            _util = NULL;
            
            return nil;
        }
        
        // load model data from disk
        iResult = _shapeReco->loadModelData();
        if(iResult != SUCCESS)
        {
            cout << endl << iResult << ": Error loading model data for Shape Recognizer" << endl;
            _engine->deleteShapeRecognizer(_shapeReco);
            _shapeReco = NULL;
            delete _util;
            _util = NULL;
            
            return nil;
        }
        
        _shapeReco->setDeviceContext(captureDevice);
        
        
        /* create numeral recognizer */
        _numeralReco = NULL;
        recoName = "SHAPEREC_NUMERALS";
        _engine->createShapeRecognizer(recoName, &_numeralReco);
        if(_numeralReco == NULL)
        {
            cout << endl << "Error creating Numeral Recognizer" << endl;
            delete _util;
            _util = NULL;
            
            return nil;
        }
        
        // load model data from disk
        iResult = _numeralReco->loadModelData();
        if(iResult != SUCCESS)
        {
            cout << endl << iResult << ": Error loading model data for Numeral Recognizer" << endl;
            _engine->deleteShapeRecognizer(_numeralReco);
            _numeralReco = NULL;
            delete _util;
            _util = NULL;
            
            return nil;
        }
        
        _numeralReco->setDeviceContext(captureDevice);
    }
    
    return self;
}

- (void)dealloc
{
    if(_util != NULL)
    {
        delete _util;
        _util = NULL;
    }
    
    if(_engine)
    {
        if(_shapeReco != NULL)
        {
            _engine->deleteShapeRecognizer(_shapeReco);
            _shapeReco = NULL;
        }
        
        _engine = NULL;
    }
    
}

- (AGHandwritingRecognizerFigure)recognizeNumeralInView:(UIView *)view
                                                  trace:(const LTKTrace &)trace
{
	LTKScreenContext screenContext;
	vector<int> shapeSubset;
	int numChoices = 1;
	float confThreshold = 0.5f;
	vector<LTKShapeRecoResult> results;
	LTKTraceGroup traceGroup;
    
    screenContext.setBboxLeft(view.bounds.origin.x);
    screenContext.setBboxRight(view.bounds.origin.x+view.bounds.size.width);
    screenContext.setBboxTop(view.bounds.origin.y);
    screenContext.setBboxBottom(view.bounds.origin.y+view.bounds.size.height);
    
    traceGroup.addTrace(trace);
    
	int iResult = _numeralReco->recognize(traceGroup, screenContext,
                                          shapeSubset, confThreshold,
                                          numChoices, results);
	if(iResult != SUCCESS)
	{
		cout << iResult << ": Error while recognizing." << endl;
        return AG_FIGURE_NONE;
	}
    
    if(results.size())
    {
        return g_figureForNumeralShape[results[0].getShapeId()];
    }
    
    return AG_FIGURE_NONE;
}


- (AGHandwritingRecognizerFigure)recognizeShapeInView:(UIView *)view
                                                trace:(const LTKTrace &)trace
{
	LTKScreenContext screenContext;
	vector<int> shapeSubset;
	int numChoices = 1;
	float confThreshold = 0.5f;
	vector<LTKShapeRecoResult> results;
	LTKTraceGroup traceGroup;
    
    screenContext.setBboxLeft(view.bounds.origin.x);
    screenContext.setBboxRight(view.bounds.origin.x+view.bounds.size.width);
    screenContext.setBboxTop(view.bounds.origin.y);
    screenContext.setBboxBottom(view.bounds.origin.y+view.bounds.size.height);
    
    traceGroup.addTrace(trace);
    
	int iResult = _shapeReco->recognize(traceGroup, screenContext,
                                        shapeSubset, confThreshold,
                                        numChoices, results);
	if(iResult != SUCCESS)
	{
		cout << iResult << ": Error while recognizing." << endl;
        return AG_FIGURE_NONE;
	}
    
    if(results.size())
    {
        return g_figureForShape[results[0].getShapeId()];
    }
    
    return AG_FIGURE_NONE;
}


@end
