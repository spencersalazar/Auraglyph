//
//  AGDTWHandwritingRecognizer.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 7/12/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGHandwritingRecognizer.h"
#include "pkmDTW.h"
#include "GRT.h"

class AGDTWHandwritingRecognizer : public AGHandwritingRecognizer
{
public:
    AGDTWHandwritingRecognizer();
    ~AGDTWHandwritingRecognizer();
    
    AGHandwritingRecognizerFigure recognizeNumeral(const LTKTrace &trace) override;
    AGHandwritingRecognizerFigure recognizeShape(const LTKTrace &trace) override;
    
    void addSample(const LTKTraceGroup &tg, AGHandwritingRecognizerFigure num) override;
    
private:
    std::vector<int> m_exampleToClass;
    pkmDTW m_dtw;
    
    std::vector<int> m_exampleToShape;
    GRT::DTW m_dtwShapes;
};

