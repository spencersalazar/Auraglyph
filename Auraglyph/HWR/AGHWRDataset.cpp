//
//  AGHWRDataset.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 6/23/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGHWRDataset.h"
#include "AGFileManager.h"
#include "spstring.h"
#include <sstream>

using namespace std;

MultiStroke AGHWRDataset::loadExampleFromFile(const string &filepath)
{
    MultiStroke ms;
    
    ms.strokes.push_back(vector<Point2D>());
    
    vector<string> lines = AGFileManager::instance().getLines(filepath);
    for (auto line : lines) {
        if (line.size() == 0) {
            ms.strokes.push_back(vector<Point2D>());
        } else {
            vector<string> fields = split(line, ' ');
            if (fields.size() >= 4) {
                float x = stof(fields[2]);
                float y = stof(fields[3]);
                ms.strokes.back().push_back(Point2D(x, y));
            }
        }
    }
    
    return ms;
}

AGHWRDataset AGHWRDataset::loadNumerals()
{
    AGFileManager &fileManager = AGFileManager::instance();
    
    std::string resourcesDir = fileManager.resourcesDirectory();
    std::string datasetPath = resourcesDir + "/" + "datasets/numerals";
    
    AGHWRDataset dataset;
    
    string classNames[] = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", };
    for (string _className : classNames) {
        int _class = dataset.addClass(_className);
        string classPath = datasetPath + "/" + _className;
        vector<string> dir = fileManager.listDirectory(classPath);
        for (string exampleFile : dir) {
            if (fileManager.fileHasExtension(exampleFile, "txt")) {
                string examplePath = classPath + "/" + exampleFile;
                MultiStroke example = loadExampleFromFile(examplePath);
                dataset.addExample(_class, example);
            }
        }
    }
    
    return dataset;
}

AGHWRDataset AGHWRDataset::loadShapes()
{
    AGFileManager &fileManager = AGFileManager::instance();
    
    std::string resourcesDir = fileManager.resourcesDirectory();
    std::string datasetPath = resourcesDir + "/" + "datasets/shapes";
    
    AGHWRDataset dataset;
    
    string classNames[] = { "circle", "square" };
    for (string _className : classNames) {
        int _class = dataset.addClass(_className);
        string classPath = datasetPath + "/" + _className;
        vector<string> dir = fileManager.listDirectory(classPath);
        for (string exampleFile : dir) {
            if (fileManager.fileHasExtension(exampleFile, "txt")) {
                string examplePath = classPath + "/" + exampleFile;
                MultiStroke example = loadExampleFromFile(examplePath);
                dataset.addExample(_class, example);
            }
        }
    }
    
    return dataset;
}

AGHWRDataset::AGHWRDataset()
{ }

AGHWRDataset::~AGHWRDataset()
{ }

int AGHWRDataset::addClass(const std::string &name)
{
    if (!m_classes.count(name)) {
        int _class = (int) m_classes.size();
        m_dataset.push_back(std::vector<MultiStroke>());
        m_classes[name] = _class;
        return _class;
    } else {
        return m_classes[name];
    }
}

std::string AGHWRDataset::getClassName(int _class)
{
    for (auto kv : m_classes) {
        if (kv.second == _class) {
            return kv.first;
        }
    }
    
    return "";
}

void AGHWRDataset::addExample(int _class, const MultiStroke &strokes)
{
    m_dataset[_class].push_back(strokes);
}

const std::vector<MultiStroke> &AGHWRDataset::examplesForClass(int _class) const
{
    return m_dataset[_class];
}
