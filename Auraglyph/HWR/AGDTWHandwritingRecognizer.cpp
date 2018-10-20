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


static GRT::MatrixFloat traceToMatrixFloat(const LTKTrace &trace)
{
    GRT::MatrixFloat mf;
    
    for (int i = 0; i < trace.getNumberOfPoints(); i++) {
        floatVector pt;
        trace.getPointAt(i, pt);
        GRT::VectorFloat vf(2);
        vf[0] = pt[0]; vf[1] = pt[1];
        mf.push_back(vf);
    }
    
    return mf;
}

static Mat multistrokeToMat(const MultiStroke &multistroke, int strokeNum = 0)
{
    Mat mat;
    
    for (auto pt : multistroke.strokes[strokeNum]) {
        mat.push_back((std::vector<float>){ pt.x, pt.y });
    }
    
    return mat;
}

static GRT::MatrixFloat multistrokeToMatrixFloat(const MultiStroke &multistroke, int strokeNum = 0)
{
    GRT::MatrixFloat mf;
    
    for (auto pt : multistroke.strokes[strokeNum]) {
        GRT::VectorFloat vf(2);
        vf[0] = pt.x; vf[1] = pt.y;
        mf.push_back(vf);
    }
    
    return mf;
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

static AGHandwritingRecognizerFigure g_figureForShape[] =
{
    AG_FIGURE_CIRCLE,
    AG_FIGURE_SQUARE,
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
    
    AGHWRDataset shapesDataset = AGHWRDataset::loadShapes();
    GRT::TimeSeriesClassificationData trainingData;
    trainingData.setNumDimensions(2);
    
    for (int cls = 0; cls < shapesDataset.numClasses(); cls++) {
        auto examples = dataset.examplesForClass(cls);
        for (auto example : examples) {
            // only consider first stroke
            GRT::MatrixFloat exMat = multistrokeToMatrixFloat(example, 0);
            trainingData.addSample(cls, exMat);
        }
    }

    m_dtwShapes.train_(trainingData);
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
    GRT::MatrixFloat mat = traceToMatrixFloat(trace);
    bool success = m_dtwShapes.predict_(mat);
    
    if (success) {
        int cls = m_dtwShapes.getPredictedClassLabel();
        double maximumLikelihood = m_dtwShapes.getMaximumLikelihood();
        
        if (maximumLikelihood > 0.5)
            return g_figureForShape[cls];
    }

    return AG_FIGURE_NONE;
}

void AGDTWHandwritingRecognizer::addSample(const LTKTraceGroup &tg, AGHandwritingRecognizerFigure num)
{
    // 
}

