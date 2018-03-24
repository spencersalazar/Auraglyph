#!/usr/bin/python

points = [1, 1, 2, 2, 2, 2, 2, 2, 4, 4, 4, 5, 5, 5]
p = 3

min = 0
max = len(points)
ix = min + (max-min)/2
ix_next = 0
while max-min > 1:
    if p < points[ix]:
        max = ix
    else:
        min = ix
    ix = min + (max-min)/2

print "ix: %i" % ix
