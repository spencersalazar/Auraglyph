//
//  AGDTWHandwritingRecognizer.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 7/12/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGDTWHandwritingRecognizer.h"
#include "AGHWRDataset.h"

static Mat traceToMat(const LTKTrace &trace)
{
    Mat mat;
    
    for (int i = 0; i < trace.getNumberOfPoints(); i++) {
        floatVector pt;
        trace.getPointAt(i, pt);
        mat.push_back(pt);
    }
    
    return mat;
}

static Mat multistrokeToMat(const MultiStroke &multistroke, int strokeNum = 0)
{
    Mat mat;
    
    for (auto pt : multistroke.strokes[strokeNum]) {
        mat.push_back((std::vector<float>){ pt.x, pt.y });
    }
    
    return mat;
}

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

AGDTWHandwritingRecognizer::AGDTWHandwritingRecognizer()
{
    AGHWRDataset dataset = AGHWRDataset::loadNumerals();
    
    for (int cls = 0; cls < dataset.numClasses(); cls++) {
        auto examples = dataset.examplesForClass(cls);
        for (auto example : examples) {
            // only consider first stroke
            Mat exMat = multistrokeToMat(example, 0);
            m_dtw.addToDatabase(exMat);
            m_exampleToClass.push_back(cls);
        }
    }
}

AGDTWHandwritingRecognizer::~AGDTWHandwritingRecognizer()
{ }

AGHandwritingRecognizerFigure AGDTWHandwritingRecognizer::recognizeNumeral(const LTKTrace &trace)
{
    Mat stroke = traceToMat(trace);
    float dist;
    int i;
    vector<int> bestPathI, bestPathJ;
    m_dtw.getNearestCandidate(stroke, dist, i, bestPathI, bestPathJ);
    int cls = m_exampleToClass[i];
    return g_figureForNumeralShape[cls];
}

AGHandwritingRecognizerFigure AGDTWHandwritingRecognizer::recognizeShape(const LTKTrace &trace)
{
    return AG_FIGURE_NONE;
}

void AGDTWHandwritingRecognizer::addSample(const LTKTraceGroup &tg, AGHandwritingRecognizerFigure num)
{
    // 
}

