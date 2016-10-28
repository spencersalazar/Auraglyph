#ifndef _GeometricRecognizerIncluded_
#define _GeometricRecognizerIncluded_

#include <limits>
#include <iostream>
#include "GeometricRecognizerTypes.h"
#include "GestureTemplate.h"
#include "SampleGestures.h"

using namespace std;

namespace DollarRecognizer
{
	class GeometricRecognizer
	{
	protected:
		//--- These are variables because C++ doesn't (easily) allow
		//---  constants to be floating point numbers
		double halfDiagonal;
		double angleRange;
		double anglePrecision;
		double goldenRatio;

		//--- How many points we use to define a shape
		int numPointsInGesture;
		//---- Square we resize the shapes to
		int squareSize;
		
		bool shouldIgnoreRotation;

		//--- What we match the input shape against
		GestureTemplates templates;

	public:
		GeometricRecognizer();

		int addTemplate(string name, Path2D points);
		DollarRecognizer::Rectangle boundingBox(Path2D points);
		Point2D centroid(Path2D points);
		double getDistance(Point2D p1, Point2D p2);
		bool   getRotationInvariance() { return shouldIgnoreRotation; }
		double distanceAtAngle(
			Path2D points, GestureTemplate aTemplate, double rotation);
		double distanceAtBestAngle(Path2D points, GestureTemplate T);
		Path2D normalizePath(Path2D points);
		double pathDistance(Path2D pts1, Path2D pts2);
		double pathLength(Path2D points);
		RecognitionResult recognize(Path2D points);
		Path2D resample(Path2D points);
		Path2D rotateBy(Path2D points, double rotation);
		Path2D rotateToZero(Path2D points);
		Path2D scaleToSquare(Path2D points);
		void   setRotationInvariance(bool ignoreRotation);
		Path2D translateToOrigin(Path2D points);

		void loadTemplates();
	};
}
#endif