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
#include "AGDTWHandwritingRecognizer.h"
#include "AGFileManager.h"
#include "spstring.h"

#include <iostream>
#include <sstream>

const string AG_HWR_FIGURESPATH = "saved-figures";

static std::map<AGHandwritingRecognizerFigure, std::string> s_figureToName = {
    {AG_FIGURE_NONE, "none"},
    {AG_FIGURE_0, "0"},
    {AG_FIGURE_1, "1"},
    {AG_FIGURE_2, "2"},
    {AG_FIGURE_3, "3"},
    {AG_FIGURE_4, "4"},
    {AG_FIGURE_5, "5"},
    {AG_FIGURE_6, "6"},
    {AG_FIGURE_7, "7"},
    {AG_FIGURE_8, "8"},
    {AG_FIGURE_9, "9"},
    {AG_FIGURE_CIRCLE, "circle"},
    {AG_FIGURE_SQUARE, "square"},
};


AGHandwritingRecognizer &AGHandwritingRecognizer::shapeRecognizer()
{
    static AGLipiTkHandwritingRecognizer s_shapeRecognizer;
    return s_shapeRecognizer;
}

AGHandwritingRecognizer &AGHandwritingRecognizer::numeralRecognizer()
{
    static AGDTWHandwritingRecognizer s_numeralRecognizer;
    return s_numeralRecognizer;
}

void AGHandwritingRecognizer::_saveFigure(const string &type, AGHandwritingRecognizerFigure figure, const LTKTrace &trace)
{
    if (trace.getNumberOfPoints() < 2)
        return;
    
    AGFileManager &fileManager = AGFileManager::instance();
    string figureName = s_figureToName[figure];
    string figuresPath = pathJoin({ fileManager.documentDirectory(), AG_HWR_FIGURESPATH, type, figureName });
    vector<string> files = fileManager.listDirectory(figuresPath);
    // todo: faster way to find next file number
    int max = 0;
    for (string file : files) {
        int num = 0;
        if (sscanf(file.c_str(), "figure%d.txt", &num) && num > max) {
            max = num;
        }
    }
    
    ostringstream filepathStream;
    filepathStream << figuresPath << "/figure" << std::setfill('0') << std::setw(5) << (max+1) << ".txt";
    ostringstream contentStream;
    for (int i = 0; i < trace.getNumberOfPoints(); i++) {
        floatVector pt;
        trace.getPointAt(i, pt);
        // strokeNum / time / x / y / pressure
        contentStream << 0 << " " << 0.0f << " " << pt[0] << " " << pt[1] << " " << 0.0f << endl;
    }
    fprintf(stderr, "writing figure to %s\n", filepathStream.str().c_str());
    fileManager.writeToFile(filepathStream.str(), contentStream.str());
}
