//
//  AGRasterSVMHandwritingRecognizer.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 7/7/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGHandwritingRecognizer.h"
#include "AGHWRRasterSVM.h"

class AGRasterSVMHandwritingRecognizer : public AGHandwritingRecognizer
{
public:
    AGRasterSVMHandwritingRecognizer();
    ~AGRasterSVMHandwritingRecognizer();
    
    AGHandwritingRecognizerFigure recognizeNumeral(const LTKTrace &trace) override;
    AGHandwritingRecognizerFigure recognizeShape(const LTKTrace &trace) override;
    
    void addSample(const LTKTraceGroup &tg, AGHandwritingRecognizerFigure num) override;
    
private:
    AGHWRRasterSVMModel *m_model = nullptr;
};

