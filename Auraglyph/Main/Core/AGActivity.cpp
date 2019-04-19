//
//  AGActivity.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 1/4/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGActivity.h"
#include "AGActivities.h"


const AGActivity::Type AGActivity::EditParamActivityType = "EditParam";
const AGActivity::Type AGActivity::DrawNodeActivityType = "DrawNodeG";
const AGActivity::Type AGActivity::CreateNodeActivityType = "CreateNode";
const AGActivity::Type AGActivity::MoveNodeActivityType = "MoveNode";
const AGActivity::Type AGActivity::DeleteNodeActivityType = "DeleteNode";
const AGActivity::Type AGActivity::CreateConnectionActivityType = "CreateConnection";
const AGActivity::Type AGActivity::DeleteConnectionActivityType = "DeleteConnection";


//------------------------------------------------------------------------------
// ### AGActivity ###
//------------------------------------------------------------------------------
#pragma mark - AGActivity

AGActivity *AGActivity::editParamActivity(AGNode *node, int port, float oldValue, float newValue)
{
    return new AG::Activities::EditParam(node, port, oldValue, newValue);
}

AGActivity *AGActivity::drawNodeActivity(AGHandwritingRecognizerFigure figure)
{
    return new AG::Activities::DrawNode(figure);
}

AGActivity *AGActivity::createNodeActivity(AGNode *node)
{
    return new AG::Activities::CreateNode(node);
}

AGActivity *AGActivity::moveNodeActivity(AGNode *node, const GLvertex3f &oldPos, const GLvertex3f &newPos)
{
    return new AG::Activities::MoveNode(node, oldPos, newPos);
}

AGActivity *AGActivity::deleteNodeActivity(AGNode *node)
{
    return new AG::Activities::DeleteNode(node);
}

AGActivity *AGActivity::createConnectionActivity(AGConnection *connection)
{
    return new AG::Activities::CreateConnection(connection);
}

AGActivity *AGActivity::deleteConnectionActivity(AGConnection *connection)
{
    return new AG::Activities::DeleteConnection(connection);
}



