//
//  AGRasterSVMHandwritingRecognizer.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 7/7/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGRasterSVMHandwritingRecognizer.h"


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


AGRasterSVMHandwritingRecognizer::AGRasterSVMHandwritingRecognizer()
{
    AGHWRDataset dataset = AGHWRDataset::loadNumerals();
    
    AGHWRRasterSVMTrainer trainer(dataset);
    m_model = trainer.getModel();
}

AGRasterSVMHandwritingRecognizer::~AGRasterSVMHandwritingRecognizer()
{
    SAFE_DELETE(m_model);
}

AGHandwritingRecognizerFigure AGRasterSVMHandwritingRecognizer::recognizeNumeral(const LTKTrace &trace)
{
    MultiStroke strokes;
    strokes.strokes.push_back(vector<Point2D>());
    for (int i = 0; i < trace.getNumberOfPoints(); i++) {
        floatVector pt;
        trace.getPointAt(i, pt);
        strokes.strokes[0].push_back(Point2D(pt[0], pt[1]));
    }
    
    int cls = m_model->predict(strokes);
    
    if (cls != -1) {
        AGHandwritingRecognizerFigure figure = g_figureForNumeralShape[cls];
        _saveFigure("numerals", figure, trace);
        return figure;
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
    
    if(area < PERIOD_AREA_MAX && trace.getNumberOfPoints() < PERIOD_NUMPOINTS_MAX) {
        _saveFigure("numerals", AG_FIGURE_PERIOD, trace);
        return AG_FIGURE_PERIOD;
    }
    //    fprintf(stderr, "area: %f number of points: %i\n", (maxX - minX)*(maxY - minY), trace.getNumberOfPoints());
    
    _saveFigure("numerals", AG_FIGURE_NONE, trace);
    
    return AG_FIGURE_NONE;
}

AGHandwritingRecognizerFigure AGRasterSVMHandwritingRecognizer::recognizeShape(const LTKTrace &trace)
{
    return AG_FIGURE_NONE;
}

void AGRasterSVMHandwritingRecognizer::addSample(const LTKTraceGroup &tg, AGHandwritingRecognizerFigure num)
{
    
}

