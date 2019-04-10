#include "Cubic.h"

namespace easing {

float cubic::easeIn (float t,float b , float c, float d) {
    t /= d;
	return c*t*t*t + b;
}
float cubic::easeOut(float t,float b , float c, float d) {
    t = t/d-1;
	return c*(t*t*t + 1) + b;
}

float cubic::easeInOut(float t, float b , float c, float d) {
    t /= d/2;
	if (t < 1) return c/2*t*t*t + b;
    t -= 2;
	return c/2*(t*t*t + 2) + b;
}

}
