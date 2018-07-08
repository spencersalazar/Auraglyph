//
//  AGHandwritingRecognizer.m
//  Auragraph
//
//  Created by Spencer Salazar on 8/9/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGHandwritingRecognizer.h"

#include "AGLipiTkHandwritingRecognizer.h"
#include "AGRasterSVMHandwritingRecognizer.h"


AGHandwritingRecognizer &AGHandwritingRecognizer::shapeRecognizer()
{
    static AGLipiTkHandwritingRecognizer s_shapeRecognizer;
    return s_shapeRecognizer;
}

AGHandwritingRecognizer &AGHandwritingRecognizer::numeralRecognizer()
{
    static AGRasterSVMHandwritingRecognizer s_numeralRecognizer;
    return s_numeralRecognizer;
}

