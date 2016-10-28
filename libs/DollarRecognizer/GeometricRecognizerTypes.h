#ifndef _GeometricRecognizerTypesIncluded_
#define _GeometricRecognizerTypesIncluded_

/*
* This code taken (and modified) from the javascript version of:
* The $1 Gesture Recognizer
*
*		Jacob O. Wobbrock
* 		The Information School
*		University of Washington
*		Mary Gates Hall, Box 352840
*		Seattle, WA 98195-2840
*		wobbrock@u.washington.edu
*
*		Andrew D. Wilson
*		Microsoft Research
*		One Microsoft Way
*		Redmond, WA 98052
*		awilson@microsoft.com
*
*		Yang Li
*		Department of Computer Science and Engineering
* 		University of Washington
*		The Allen Center, Box 352350
*		Seattle, WA 98195-2840
* 		yangli@cs.washington.edu
*/
#include <math.h>
#include <string>
#include <list>
#include <vector>

using namespace std;

namespace DollarRecognizer
{
	class Point2D
	{
	public:
		//--- Wobbrock used doubles for these, not ints
		//int x, y;
		double x, y;
		Point2D() 
		{
			this->x=0; 
			this->y=0;
		}
		Point2D(double x, double y)
		{
			this->x = x;
			this->y = y;
		}
	};

	typedef vector<Point2D>  Path2D;
	typedef Path2D::iterator Path2DIterator;

	class Rectangle
	{
	public:
		double x, y, width, height;
		Rectangle(double x, double y, double width, double height)
		{
			this->x = x;
			this->y = y;
			this->width = width;
			this->height = height;
		}
	};

	class RecognitionResult
	{
	public:
		string name;
		double score;
		RecognitionResult(string name, double score)
		{
			this->name = name;
			this->score = score;
		}
	};
}
#endif