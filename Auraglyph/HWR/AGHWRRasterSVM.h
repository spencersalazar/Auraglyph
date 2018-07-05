//
//  AGHWRRasterSVM.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 6/23/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#pragma once

#include <vector>

#include "AGHWRDataset.h"

struct Grid
{
    std::vector<std::vector<float>> grid;
};

class svm_model;
class svm_problem;

class AGHWRRasterSVMModel
{
public:
    
    AGHWRRasterSVMModel(svm_problem *problem, svm_model *model)
    : m_problem(problem), m_model(model)
    { }
    
    ~AGHWRRasterSVMModel();

    int predict(const MultiStroke& strokes);
    
private:
    svm_problem *m_problem = nullptr;
    svm_model *m_model = nullptr;
};

class AGHWRRasterSVMTrainer
{
public:
    
    AGHWRRasterSVMTrainer(int numClasses);
    AGHWRRasterSVMTrainer(const AGHWRDataset &dataset);
    ~AGHWRRasterSVMTrainer();
    
    void addExample(int _class, const MultiStroke& example);
    AGHWRRasterSVMModel *train();
    AGHWRRasterSVMModel *train(const AGHWRDataset &dataset);
    AGHWRRasterSVMModel *getModel() const;

private:
    
    struct Example
    {
        int _class;
        Grid raster;
    };
    
    int m_numClasses = 0;
    std::vector<Example> m_trainingData;
    AGHWRRasterSVMModel *m_model = nullptr;
};

