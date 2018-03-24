#!/usr/bin/python

import random
import math

Npoints = 100
Ntests = 100

class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y
    
    def dist(self, p):
        return math.sqrt((self.x-p.x)*(self.x-p.x) + (self.y-p.y)*(self.y-p.y))
    
    def x1norm(self, p):
        return math.fabs(self.x-p.x)
    
    def y1norm(self, p):
        return math.fabs(self.y-p.y)
    
    def getX(self):
        return self.x
    
    def getY(self):
        return self.y
    
    def __str__(self):
        return "(%f, %f)" % (self.x, self.y)
    

random.seed()

# generate points
points = []
for i in range(0,Npoints):
    points.append(Point(random.uniform(-1,1), random.uniform(-1,1)))

# sort in X/Y
points_x = sorted(points, key=Point.getX)
points_y = sorted(points, key=Point.getY)

# test
for i in range(0,Ntests):
    p = Point(random.uniform(-1,1), random.uniform(-1,1))
    
    # test sorted x/y
    
    # find closest in x
    min = 0
    max = len(points_x)
    ix = min + (max-min)/2
    while max-min > 1:
        if p.x < points_x[ix].x:
            max = ix
        else:
            min = ix
        ix = min + (max-min)/2
    # p.x is less than all x's after points_x[ix].x
    if ix+1 < len(points_x) and points_x[ix+1].x1norm(p) < points_x[ix].x1norm(p):
        ix_min_dist = ix+1
    else:
        ix_min_dist = ix
    
    # find closest in y
    min = 0
    max = len(points_y)
    iy = min + (max-min)/2
    while max-min > 1:
        if p.y < points_y[iy].y:
            max = iy
        else:
            min = iy
        iy = min + (max-min)/2
    # p.x is less than all x's after points_x[ix].x
    if iy+1 < len(points_y) and points_y[iy+1].y1norm(p) < points_y[iy].y1norm(p):
        iy_min_dist = iy+1
    else:
        iy_min_dist = iy
    
    if points_x[ix_min_dist].dist(p) < points_y[iy_min_dist].dist(p):
        p_sortedxy = points_x[ix_min_dist]
        p_reject = points_y[iy_min_dist]
    else:
        p_sortedxy = points_y[iy_min_dist]
        p_reject = points_x[ix_min_dist]
    
    # test linear brute force
    
    mindist = float("inf")
    p_lbf = None
    for pp in points:
        if pp.dist(p) < mindist:
            mindist = pp.dist(p)
            p_lbf = pp
    
    # compare results
    if p_lbf.x != p_sortedxy.x and p_lbf.y != p_sortedxy.y:
        print "mismatch: p=%s, p_lbf=%s, p_sortedxy=%s, p_reject=%s" % (p, p_lbf, p_sortedxy, p_reject)
        break






