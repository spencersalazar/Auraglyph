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

#import "SSZipArchive.h"


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
    AG_FIGURE_NONE,
};

static AGHandwritingRecognizerFigure g_figureForShape[] =
{
    AG_FIGURE_CIRCLE,
    AG_FIGURE_SQUARE,
    AG_FIGURE_TRIANGLE_UP,
    AG_FIGURE_TRIANGLE_DOWN,
    AG_FIGURE_NONE,
};


@interface AGHandwritingRecognizer ()
{
    LTKOSUtil* _util;
    LTKLipiEngineInterface *_engine;
    LTKShapeRecognizer * _numeralReco;
    LTKShapeRecognizer * _shapeReco;
}

- (void)loadData;

@end


static AGHandwritingRecognizer * g_instance = NULL;

@implementation AGHandwritingRecognizer

@synthesize view;

+ (id)instance
{
    if(g_instance == NULL)
        g_instance = [AGHandwritingRecognizer new];
    return g_instance;
}

+ (NSString *)projectPath
{
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
             objectAtIndex:0] stringByAppendingPathComponent:@"projects"];
}

+ (void)listRecursive:(NSString *)path indent:(NSString *)indent
{
    NSFileManager *manager = [NSFileManager defaultManager];
    
    NSError *error = NULL;
    NSArray *files = [manager contentsOfDirectoryAtPath:path error:&error];
    for(NSString *file in files)
    {
        NSString *fullPath = [path stringByAppendingPathComponent:file];
        NSDictionary *attributes = [manager attributesOfItemAtPath:fullPath error:&error];
        short permissions = [attributes[NSFilePosixPermissions] shortValue];
        
        BOOL canRead = [manager isReadableFileAtPath:fullPath];
        BOOL canWrite = [manager isWritableFileAtPath:fullPath];
        BOOL canExec = [manager isExecutableFileAtPath:fullPath];
        
        NSLog(@"%@%@ %o %s%s%s", indent, file, permissions, canRead?"r":"-", canWrite?"w":"-", canExec?"x":"-");
        BOOL isDir = NO;
        if([manager fileExistsAtPath:fullPath isDirectory:&isDir] && isDir)
            [AGHandwritingRecognizer listRecursive:fullPath indent:[indent stringByAppendingString:@"- "]];
    }
}

- (id)init
{
    if(self = [super init])
    {
        if(![[NSFileManager defaultManager] fileExistsAtPath:[AGHandwritingRecognizer projectPath]])
            [self loadData];
        
        int iResult;
        
        // get util object
        _util = LTKOSUtilFactory::getInstance();
        
        // create engine
        _engine = createLTKLipiEngine();
        
        // set root path for projects
        _engine->setLipiRootPath([[[AGHandwritingRecognizer projectPath] stringByDeletingLastPathComponent] UTF8String]);
        
        NSLog(@"project path: %@", [AGHandwritingRecognizer projectPath]);
        // [AGHandwritingRecognizer listRecursive:[[AGHandwritingRecognizer projectPath] stringByDeletingLastPathComponent] indent:@""];
        
        
        // initialize
        iResult = _engine->initializeLipiEngine();
        if(iResult != SUCCESS)
        {
            cout << iResult <<": Error initializing LipiEngine." << endl;
            NSLog(@"Error initializing LipiEngine (%i)", iResult);
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
            NSLog(@"Error creating Shape Recognizer");
            delete _util;
            _util = NULL;
            
            return nil;
        }
        
        // load model data from disk
        iResult = _shapeReco->loadModelData();
        if(iResult != SUCCESS)
        {
            cout << endl << iResult << ": Error loading model data for Shape Recognizer" << endl;
            NSLog(@"Error loading model data for Shape Recognizer (%i)", iResult);
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
            NSLog(@"Error creating Numeral Recognizer");
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
            NSLog(@"Error loading model data for Numeral Recognizer (%i)", iResult);
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


- (void)loadData
{
    NSLog(@"copying LipiTk model data");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [fileManager removeItemAtPath:[AGHandwritingRecognizer projectPath] error:NULL];
    
//    [SSZipArchive unzipFileAtPath:[[NSBundle mainBundle] pathForResource:@"projects.zip" ofType:@""]
//                    toDestination:[[AGHandwritingRecognizer projectPath] stringByDeletingLastPathComponent]];
    NSError *error = NULL;
    NSString *projectSrcPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"projects"];
    NSString *projectDstPath = [AGHandwritingRecognizer projectPath];
    [fileManager copyItemAtPath:projectSrcPath toPath:projectDstPath error:&error];
    if(error != NULL)
        NSLog(@"-[AGHandwritingRecognizer loadData]: error copying model data: %@", error.localizedDescription);
}


- (AGHandwritingRecognizerFigure)recognizeNumeral:(const LTKTrace &)trace
{
	LTKScreenContext screenContext;
	vector<int> shapeSubset;
	int numChoices = 1;
	float confThreshold = 0.5f;
	vector<LTKShapeRecoResult> results;
	LTKTraceGroup traceGroup;
    
    screenContext.setBboxLeft(self.view.bounds.origin.x);
    screenContext.setBboxRight(self.view.bounds.origin.x+view.bounds.size.width);
    screenContext.setBboxTop(self.view.bounds.origin.y);
    screenContext.setBboxBottom(self.view.bounds.origin.y+view.bounds.size.height);
    
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
    
    // detect period
    const float PERIOD_AREA_MAX = 225;
    const int PERIOD_NUMPOINTS_MAX = 30;
    
    float minX = FLT_MAX, maxX = FLT_MIN, minY = FLT_MAX, maxY = FLT_MIN;
    for(int i = 0; i < trace.getNumberOfPoints(); i++)
    {
        floatVector p;
        trace.getPointAt(i, p);
        if(p[0] < minX) minX = p[0];
        if(p[0] > maxX) maxX = p[0];
        if(p[1] < minY) minY = p[1];
        if(p[1] > maxY) maxY = p[1];
    }
    
    float area = (maxX - minX)*(maxY - minY);
    
    if(area < PERIOD_AREA_MAX && trace.getNumberOfPoints() < PERIOD_NUMPOINTS_MAX)
        return AG_FIGURE_PERIOD;
//    fprintf(stderr, "area: %f number of points: %i\n", (maxX - minX)*(maxY - minY), trace.getNumberOfPoints());
    
    return AG_FIGURE_NONE;
}

- (void)addSample:(const LTKTraceGroup &)tg forNumeral:(AGHandwritingRecognizerFigure)num
{
    int shapeID = 0;
    while(g_figureForNumeralShape[shapeID] != num && g_figureForNumeralShape[shapeID] != AG_FIGURE_NONE)
        shapeID++;
    
    if(g_figureForNumeralShape[shapeID] != AG_FIGURE_NONE)
        _numeralReco->addSample(tg, shapeID);
}


- (AGHandwritingRecognizerFigure)recognizeShape:(const LTKTrace &)trace
{
	LTKScreenContext screenContext;
	vector<int> shapeSubset;
	int numChoices = 1;
	float confThreshold = 0.5f;
	vector<LTKShapeRecoResult> results;
	LTKTraceGroup traceGroup;
    
    screenContext.setBboxLeft(self.view.bounds.origin.x);
    screenContext.setBboxRight(self.view.bounds.origin.x+view.bounds.size.width);
    screenContext.setBboxTop(self.view.bounds.origin.y);
    screenContext.setBboxBottom(self.view.bounds.origin.y+view.bounds.size.height);
    
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
