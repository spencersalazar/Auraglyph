#ifndef _PathWriterIncluded_
#define _PathWriterIncluded_

#include <fstream>
#include <string>
#include "GeometricRecognizerTypes.h"

using namespace std;

namespace DollarRecognizer
{
	class PathWriter
	{
	public:
		static bool writeToFile(
			Path2D path, 
			const string fileName    = "savedPath.txt", 
			const string gestureName = "DefaultName")
		{
			fstream file(fileName.c_str(), ios::out);

			file << "Path2D getGesture" << gestureName << "()" << endl;
			file << "{" << endl;
			file << "\t" << "Path2D path;" << endl;
			
			Path2D::const_iterator i;
			for (i = path.begin(); i != path.end(); i++)
			{
				Point2D point = *i;
				file << "\t" << "path.push_back(Point2D(" << point.x << "," 
					 << point.y << "));" << endl;
			}

			file << endl;
			file << "\t" << "return path;" << endl;
			file << "}" << endl;

			file.close();

			return true;
		}
	};
}

#endif