//
//  AGHWRRasterSVM.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 6/23/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGHWRRasterSVM.h"

#include <float.h>
#include <math.h>
#include <algorithm>
#include <random>

#include "svm.h"

#define RASTER_N 15
#define RASTER_STROKE_WIDTH 1

#define NUM_AUGMENT 0
#define AUGMENT_ROT M_PI/18
#define AUGMENT_NOISE 0.02

float dist(Point2D a, Point2D b)
{
    float x = b.x-a.x;
    float y = b.y-b.y;
    return sqrtf(x*x+y*y);
}

static Grid _raster(MultiStroke strokes, int N, int strokeWidth)
{
    /* Basic rasterization of a series of strokes (sequence of 2d points)
     onto a periodic 2d grid. The basic procedure:
     - interpolate the points of each stroke so that consecutive points are
       not separated by more than 1 pixel in the resulting raster
     - translate and rescale the strokes so the whole figure is in the range
       x[0,N], y[0,N]
     - for each point x/y set the grid point g[x,y] = 1 as well as surrounding
       points if width > 0
     */
    Grid grid;
    grid.grid.resize(N);
    for(int x = 0; x < N; x++)
        grid.grid[x].resize(N);
    
    // find min/max x/y
    float xmin = FLT_MAX, xmax = 0, ymin = FLT_MAX, ymax = 0;
    for (auto stroke : strokes.strokes) {
        for (auto pt : stroke) {
            if(pt.x < xmin) xmin = pt.x;
            if(pt.x > xmax) xmax = pt.x;
            if(pt.y < ymin) ymin = pt.y;
            if(pt.y > ymax) ymax = pt.y;
        }
    }
    
    // calculate scale factor
    float scale = (N-1)/std::max(xmax-xmin, ymax-ymin);
    
    // interpolate min distance between consecutive points to scale factor
    for (auto stroke : strokes.strokes) {
        for (int i = 1; i < stroke.size(); i++) {
            float pt_dist = dist(stroke[i-1], stroke[i]);
            if (pt_dist*scale > 1) {
                // insert midpoint
                Point2D mid((stroke[i-1].x+stroke[i].x)/2.0f, (stroke[i-1].y+stroke[i].y)/2.0f);
                stroke.insert(stroke.begin()+i, mid);
            } else {
                i++;
            }
        }
    }
    
    bool centerY = xmax-xmin > ymax-ymin;
    for (int i = 0; i < strokes.strokes.size(); i++) {
        for (int j = 0; j < strokes.strokes[i].size(); j++) {
            Point2D &pt = strokes.strokes[i][j];
            // center smaller dimension
            if(centerY)
                pt.y += (xmax-xmin)/2-(ymax-ymin)/2;
            else
                pt.x += (ymax-ymin)/2-(xmax-xmin)/2;
            // rescale to (N, N)
            pt.x = (pt.x-xmin)*scale;
            pt.y = (pt.y-ymin)*scale;
            
            // set grid point
            int idxx = (int) floorf(pt.x);
            int idxy = (int) floorf(pt.y);
            grid.grid[idxx][idxy] = 1;
            // set surrounding points
            if (strokeWidth > 0) {
                if (idxy-strokeWidth >= 0)
                    grid.grid[idxx][idxy-strokeWidth] = 1;
                if (idxy+strokeWidth < N)
                    grid.grid[idxx][idxy+strokeWidth] = 1;
                if (idxx-strokeWidth >= 0)
                    grid.grid[idxx-strokeWidth][idxy] = 1;
                if (idxx+strokeWidth < N)
                    grid.grid[idxx+strokeWidth][idxy] = 1;
            }
        }
    }
    
    return grid;
}

AGHWRRasterSVMTrainer::AGHWRRasterSVMTrainer(int numClasses)
{
    m_numClasses = numClasses;
}

AGHWRRasterSVMTrainer::AGHWRRasterSVMTrainer(const AGHWRDataset &dataset)
{
    m_numClasses = dataset.numClasses();
    train(dataset);
}

AGHWRRasterSVMTrainer::~AGHWRRasterSVMTrainer()
{
}

void AGHWRRasterSVMTrainer::addExample(int _class, const MultiStroke& strokes)
{
    Example example;
    example._class = _class;
    example.raster = _raster(strokes, RASTER_N, RASTER_STROKE_WIDTH);
    m_trainingData.push_back(example);
    
    // get min/max of each dimension
    float minx = FLT_MAX, maxx = -FLT_MAX, miny = FLT_MAX, maxy = -FLT_MAX;
    for (auto stroke : strokes.strokes) {
        for (auto pt : stroke) {
            if (pt.x < minx) minx = pt.x;
            if (pt.x > maxx) maxx = pt.x;
            if (pt.y < miny) miny = pt.y;
            if (pt.y > maxy) maxy = pt.y;
        }
    }
    
    float maxdim = maxx-minx > maxy-miny ? maxx-minx : maxy-miny;
    
    auto gaussian = std::normal_distribution<float>();
    std::default_random_engine gen;
    for (int i = 0; i < NUM_AUGMENT; i++) {
        MultiStroke augment = strokes;
        float rot = gaussian(gen)*M_PI/18;
        float cs = cosf(rot), sn = sinf(rot);
        for (int j = 0; j < augment.strokes.size(); j++) {
            for (int k = 0; k < augment.strokes[j].size(); k++) {
                // rotate
                float x = augment.strokes[j][k].x, y = augment.strokes[j][k].y;
                augment.strokes[j][k].x = x*cs-y*sn;
                augment.strokes[j][k].y = x*sn+y*cs;
                // add noise
                float noisex = gaussian(gen)*maxdim*0.02, noisey = gaussian(gen)*maxdim*0.02;
                augment.strokes[j][k].x += noisex;
                augment.strokes[j][k].y += noisey;

                Example example;
                example._class = _class;
                example.raster = _raster(augment, RASTER_N, RASTER_STROKE_WIDTH);
                m_trainingData.push_back(example);
            }
        }
    }
}

AGHWRRasterSVMModel *AGHWRRasterSVMTrainer::train(const AGHWRDataset &dataset)
{
    for (int cls = 0; cls < dataset.numClasses(); cls++) {
        for (auto example : dataset.examplesForClass(cls)) {
            addExample(cls, example);
        }
    }
    
    return train();
}

AGHWRRasterSVMModel *AGHWRRasterSVMTrainer::train()
{
    svm_problem *problem = new svm_problem;
    problem->l = (int) m_trainingData.size();
    problem->y = new double[m_trainingData.size()];
    problem->x = new svm_node*[m_trainingData.size()];
    
    for(int i = 0; i < m_trainingData.size(); i++)
    {
        // label
        problem->y[i] = m_trainingData[i]._class;
        problem->x[i] = new svm_node[RASTER_N*RASTER_N+1];
        for(int y = 0; y < RASTER_N; y++)
        {
            for(int x = 0; x < RASTER_N; x++)
            {
                int j = y*RASTER_N+x;
                problem->x[i][j].index = j;
                problem->x[i][j].value = m_trainingData[i].raster.grid[x][y];
            }
        }
        // set end sentinel
        problem->x[i][RASTER_N*RASTER_N].index = -1;
    }
    
    svm_parameter param;
    param.svm_type = C_SVC;
    param.kernel_type = RBF;
    param.degree = 3;
    param.gamma = 1.0f/(RASTER_N*RASTER_N);
    param.coef0 = 0;
    param.cache_size = 100;
    param.eps = 0.001;
    param.C = 1;
    param.nu = 0.5;
    param.p = 0.1;
    param.shrinking = 1;
    param.probability = 1;
    param.nr_weight = 0;
    
    svm_model *model = svm_train(problem, &param);
    
    m_model = new AGHWRRasterSVMModel(problem, model);
    
    return m_model;
}

AGHWRRasterSVMModel *AGHWRRasterSVMTrainer::getModel() const
{
    return m_model;
}

AGHWRRasterSVMModel::~AGHWRRasterSVMModel()
{
    if (m_model != nullptr) { svm_free_and_destroy_model(&m_model); m_model = nullptr; }
    if (m_problem != nullptr) {
        delete[] m_problem->y;
        for (int i = 0; i < m_problem->l; i++) {
            delete[] m_problem->x[i];
        }
        delete[] m_problem->x;
        delete m_problem;
        m_problem = nullptr;
    }
}

int AGHWRRasterSVMModel::predict(const MultiStroke& strokes)
{
    Grid raster = _raster(strokes, RASTER_N, RASTER_STROKE_WIDTH);
    
    svm_node *node = new svm_node[RASTER_N*RASTER_N+1];
    
    for (int y = 0; y < RASTER_N; y++) {
        for (int x = 0; x < RASTER_N; x++) {
            int j = y*RASTER_N+x;
            node[j].index = j;
            node[j].value = raster.grid[x][y];
        }
    }
    // set end sentinel
    node[RASTER_N*RASTER_N].index = -1;
    
    int numClasses = svm_get_nr_class(m_model);
    double probs[numClasses];
    int _class = (int) svm_predict_probability(m_model, node, probs);
    
    delete[] node;
    
//    if (probs[_class] < 0.5) {
//        fprintf(stderr, "fails prob criterion (more than 50%% likely)\n");
//        return -1;
//    }
    
    for (int i = 0; i < numClasses; i++) {
        fprintf(stderr, "p(%i) = %lf\n", i, probs[i]);
        if (i != _class && probs[_class] <= probs[i]*2) {
            fprintf(stderr, "fails prob criterion (2x next most likely class)\n");
            return -1;
        }
    }
    
    return (int) _class;
}


