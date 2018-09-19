//
//  AGHWRDataset.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 6/23/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include <vector>
#include <string>
#include <map>

struct Point2D
{
    Point2D() : x(0), y(0) { }
    
    Point2D(float _x, float _y) : x(_x), y(_y) { }
    
    float x, y;
};

struct MultiStroke
{
    std::vector<std::vector<Point2D>> strokes;
};

class AGHWRDataset
{
public:
    
    static MultiStroke loadExampleFromFile(const std::string &filepath);
    
    static AGHWRDataset loadShapes();
    static AGHWRDataset loadNumerals();

    AGHWRDataset();
    ~AGHWRDataset();
    
    int addClass(const std::string &name);
    std::string getClassName(int _class);
    int numClasses() const { return (int) m_classes.size(); }
    
    void addExample(int _class, const MultiStroke &strokes);
    const std::vector<MultiStroke> &examplesForClass(int _class) const;
    
private:
    std::map<std::string, int> m_classes;
    std::vector<std::vector<MultiStroke>> m_dataset;
};

