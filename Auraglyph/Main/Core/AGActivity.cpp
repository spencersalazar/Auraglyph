//
//  AGActivity.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 1/4/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGActivity.h"

#include "AGNode.h"
#include "AGConnection.h"
#include "AGGraphManager.h"
#include "AGGraph.h"
#include "AGAudioManager.h"
#include "AGAudioNode.h"


const AGActivity::Type AGActivity::EditParamActivityType = "EditParam";
const AGActivity::Type AGActivity::DrawNodeActivityType = "DrawNodeG";
const AGActivity::Type AGActivity::CreateNodeActivityType = "CreateNode";
const AGActivity::Type AGActivity::MoveNodeActivityType = "MoveNode";
const AGActivity::Type AGActivity::DeleteNodeActivityType = "DeleteNode";
const AGActivity::Type AGActivity::CreateConnectionActivityType = "CreateConnection";
const AGActivity::Type AGActivity::DeleteConnectionActivityType = "DeleteConnection";


//------------------------------------------------------------------------------
// ### AGUndoableActivity ###
//------------------------------------------------------------------------------
#pragma mark - AGUndoableActivity

class AGUndoableActivity : public AGActivity
{
public:
    AGUndoableActivity(const std::string &type, const std::string &title,
                       std::function<void ()> undo, std::function<void ()> redo)
    : AGActivity(type, title), m_undo(undo), m_redo(redo)
    { }
    
    bool canUndo() const override { return true; }
    
    void undo() override { m_undo(); }
    
    void redo() override { m_redo(); }
    
private:
    std::function<void ()> m_undo;
    std::function<void ()> m_redo;
    std::function<std::string ()> m_serialize;
};


//------------------------------------------------------------------------------
// ### AGActivity ###
//------------------------------------------------------------------------------
#pragma mark - AGActivity

AGActivity *AGActivity::editParamActivity(AGNode *node, int port, float oldValue, float newValue)
{
    std::string uuid = node->uuid();
    AGUndoableActivity *action = new AGUndoableActivity(
        AGActivity::EditParamActivityType,
        "Parameter Change",
        [uuid, port, oldValue]() {
            // undo
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(uuid);
            if(node != nullptr)
                node->setEditPortValue(port, oldValue);
        },
        [uuid, port, newValue]() {
            // redo
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(uuid);
            if(node != nullptr)
                node->setEditPortValue(port, newValue);
        }
    );
    
    return action;
}

AGActivity *AGActivity::drawNodeActivity(AGHandwritingRecognizerFigure figure)
{
    return new AGActivity(AGActivity::DrawNodeActivityType, "Draw Node");
}

AGActivity *AGActivity::createNodeActivity(AGNode *node)
{
    bool isOutput = node->type() == "Output";
    AGDocument::Node serializedNode = node->serialize();
    std::string uuid = node->uuid();
    AGUndoableActivity *action = new AGUndoableActivity(
        AGActivity::CreateNodeActivityType,
        "Create Node",
        [uuid]() {
            // remove/delete the node
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(uuid);
            node->removeFromTopLevel();
        },
        [serializedNode, isOutput]() {
            // re-create/re-add the node
            AGNode *node = AGNodeManager::createNode(serializedNode);
            AGGraphManager::instance().addNodeToTopLevel(node);
            if(isOutput)
            {
                AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
                outputNode->setOutputDestination(AGAudioManager_::instance().masterOut());
            }
        }
    );
    
    return action;
}

AGActivity *AGActivity::moveNodeActivity(AGNode *node, const GLvertex3f &oldPos, const GLvertex3f &newPos)
{
    std::string uuid = node->uuid();
    AGUndoableActivity *action = new AGUndoableActivity(
        AGActivity::MoveNodeActivityType,
        "Move Node",
        [uuid, oldPos]() {
            // move the node back
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(uuid);
            node->setPosition(oldPos);
        },
        [uuid, newPos]() {
            // move the node back
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(uuid);
            node->setPosition(newPos);
        }
    );
    
    return action;
}

AGActivity *AGActivity::deleteNodeActivity(AGNode *node)
{
    bool isOutput = node->type() == "Output";
    AGDocument::Node serializedNode = node->serialize();
    std::string uuid = node->uuid();
    AGUndoableActivity *action = new AGUndoableActivity(
        AGActivity::DeleteNodeActivityType,
        "Delete Node",
        [serializedNode, isOutput]() {
            // re-create/re-add the node
            AGNode *node = AGNodeManager::createNode(serializedNode);
            AGGraphManager::instance().addNodeToTopLevel(node);
            if(isOutput)
            {
                AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
                outputNode->setOutputDestination(AGAudioManager_::instance().masterOut());
            }
            
            // todo: recreate connections
            for(auto connection : serializedNode.outbound)
                AGConnection::connect(connection);
            for(auto connection : serializedNode.inbound)
                AGConnection::connect(connection);
        },
        [uuid]() {
            // remove/delete the node
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(uuid);
            node->removeFromTopLevel();
        }
    );
    
    return action;
}

AGActivity *AGActivity::createConnectionActivity(AGConnection *connection)
{
    AGDocument::Connection serializedConnection = connection->serialize();
    std::string uuid = connection->uuid();
    AGUndoableActivity *action = new AGUndoableActivity(
        AGActivity::CreateConnectionActivityType,
        "Create Connection",
        [uuid]() {
            // delete the connection
            AGConnection *connection = AGGraphManager::instance().graph()->connectionWithUUID(uuid);
            connection->removeFromTopLevel();
        },
        [serializedConnection]() {
            // recreate the connection
            AGConnection::connect(serializedConnection);
        }
    );
    
    return action;
}

AGActivity *AGActivity::deleteConnectionActivity(AGConnection *connection)
{
    AGDocument::Connection serializedConnection = connection->serialize();
    std::string uuid = connection->uuid();
    AGUndoableActivity *action = new AGUndoableActivity(
        AGActivity::DeleteConnectionActivityType,
        "Delete Connection",
        [serializedConnection]() {
            // recreate the connection
            AGConnection::connect(serializedConnection);
        },
        [uuid]() {
            // delete the connection
            AGConnection *connection = AGGraphManager::instance().graph()->connectionWithUUID(uuid);
            connection->removeFromTopLevel();
        }
    );
    
    return action;
}



