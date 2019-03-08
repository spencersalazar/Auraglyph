//
//  AGEraseFreedrawTouchHandler.m
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import "AGEraseFreedrawTouchHandler.h"

#import "AGDef.h"
#import "Geometry.h"

#import "AGViewController.h"
#import "AGFreeDraw.h"
#import "AGAnalytics.h"


//------------------------------------------------------------------------------
// ### AGEraseFreedrawTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGEraseFreedrawTouchHandler

@implementation AGEraseFreedrawTouchHandler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex2f erasePos = [_viewController worldCoordinateForScreenCoordinate:p].xy();
    
    const list<AGFreeDraw*> &freedraws = [_viewController freedraws];
    
    float eraserThresh = 25;
    
    for(auto i = freedraws.begin(); i != freedraws.end(); )
    {
        AGFreeDraw *fd = *i++;
        assert(fd);
        
        const vector<GLvertex3f> &oldPoints = fd->points();
        
        // Hit test for whole freedraw
        for(int i = 0; i < oldPoints.size()-1; i++)
        {
            GLvertex2f p0 = oldPoints[i].xy();
            GLvertex2f p1 = oldPoints[i+1].xy();
            
            if(pointInCircle(p0, erasePos, eraserThresh) ||
               (i == oldPoints.size()-2 && pointInCircle(p1, erasePos, eraserThresh)) ||
               pointOnLine(erasePos, p0, p1, eraserThresh))
            {
                vector<vector<GLvertex3f> > newFreedraws;
                vector<GLvertex3f> newPoints;
                
                // Hit test for individual segments within freedraw
                for(int j = 0; j < oldPoints.size()-1; j++)
                {
                    GLvertex2f p0 = oldPoints[j].xy();
                    GLvertex2f p1 = oldPoints[j+1].xy();
                    
                    if(pointInCircle(p0, erasePos, eraserThresh))
                    {
                        if(newPoints.size()>1)
                        {
                            newFreedraws.push_back(newPoints);
                            newPoints.clear();
                        }
                        else
                        {
                            newPoints.clear();
                        }
                    }
                    else if((j == oldPoints.size()-2) && pointInCircle(p1, erasePos, eraserThresh))
                    {
                        if(newPoints.size()>0)
                        {
                            newPoints.push_back(oldPoints[j]);
                            newFreedraws.push_back(newPoints);
                            newPoints.clear();
                        }
                        else
                        {
                            newPoints.clear();
                        }
                    }
                    else if(pointOnLine(erasePos, p0, p1, eraserThresh))
                    {
                        if(newPoints.size()>1)
                        {
                            newPoints.push_back(oldPoints[j]);
                            newFreedraws.push_back(newPoints);
                            newPoints.clear();
                        }
                        else
                        {
                            newPoints.clear();
                        }
                    }
                    else {
                        newPoints.push_back(oldPoints[j]);
                        
                        if(j == oldPoints.size()-2)
                        {
                            newPoints.push_back(oldPoints[j+1]);
                            newFreedraws.push_back(newPoints);
                            newPoints.clear();
                        }
                    }
                }
                
                for(auto draw : newFreedraws)
                {
                    AGFreeDraw *fd_new = new AGFreeDraw(draw.data(), draw.size());
                    fd_new->init();
                    [_viewController addFreeDraw:fd_new];
                }
                
                [_viewController resignFreeDraw:fd];
                
                break; // Break out of handling this freedraw
            }
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    
}

- (void)update:(float)t dt:(float)dt { }

@end

