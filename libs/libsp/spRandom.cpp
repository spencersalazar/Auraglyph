//
//  spRandom.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 3/15/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "spRandom.h"
#include <stdlib.h>
#include <time.h>

// force constructor call
static Random g_dummyRandom;

const float RANDOM_MAX_FLOAT = 2147483647;

Random::Random()
{
    Random::seed();
}

void Random::seed()
{
    srandom((unsigned int) time(NULL));
}

float Random::unit()
{
    return random()/RANDOM_MAX_FLOAT;
}
