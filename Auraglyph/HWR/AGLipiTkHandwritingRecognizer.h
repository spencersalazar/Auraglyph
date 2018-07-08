//
//  AGLipiTkHandwritingRecognizer.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 7/7/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGHandwritingRecognizer.h"
#include "LTKLipiEngineInterface.h"
#include "LTKMacros.h"
#include "LTKInc.h"
#include "LTKTypes.h"
#include "LTKTrace.h"
#include "LTKLoggerUtil.h"
#include "LTKErrors.h"
#include "LTKOSUtilFactory.h"
#include "LTKOSUtil.h"

#include "Geometry.h"

#include <string>

class AGLipiTkHandwritingRecognizer : public _AGHandwritingRecognizer
{
public:
    AGLipiTkHandwritingRecognizer();
    ~AGLipiTkHandwritingRecognizer();

    void setBoundingBox(const GLvrectf &bbox) { m_bbox = bbox; }
    
    AGHandwritingRecognizerFigure recognizeNumeral(const LTKTrace &trace) override;
    AGHandwritingRecognizerFigure recognizeShape(const LTKTrace &trace) override;

    void addSample(const LTKTraceGroup &tg, AGHandwritingRecognizerFigure num) override;
    
private:
    GLvrectf m_bbox;
    
    LTKOSUtil* _util = nullptr;
    LTKLipiEngineInterface *_engine = nullptr;
    LTKShapeRecognizer * _numeralReco = nullptr;
    LTKShapeRecognizer * _shapeReco;
    
    void _loadData();
    std::string _projectPath();
};


