//
//  AGUndoManager.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/17/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGUndoManager.h"

#include "AGNode.h"
#include "AGConnection.h"
#include "AGGraphManager.h"
#include "AGGraph.h"
#include "AGAudioManager.h"
#include "AGAudioNode.h"

#define AG_MAX_UNDO 100

//------------------------------------------------------------------------------
// ### AGUndoAction ###
//------------------------------------------------------------------------------
#pragma mark - AGUndoAction

AGUndoAction *AGUndoAction::editParamUndoAction(AGNode *node, int port, float oldValue, float newValue)
{
    std::string uuid = node->uuid();
    AGBasicUndoAction *action = new AGBasicUndoAction(
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

AGUndoAction *AGUndoAction::createNodeUndoAction(AGNode *node)
{
    bool isOutput = node->type() == "Output";
    AGDocument::Node serializedNode = node->serialize();
    std::string uuid = node->uuid();
    AGBasicUndoAction *action = new AGBasicUndoAction(
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

AGUndoAction *AGUndoAction::moveNodeUndoAction(AGNode *node, const GLvertex3f &oldPos, const GLvertex3f &newPos)
{
    std::string uuid = node->uuid();
    AGBasicUndoAction *action = new AGBasicUndoAction(
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

AGUndoAction *AGUndoAction::deleteNodeUndoAction(AGNode *node)
{
    bool isOutput = node->type() == "Output";
    AGDocument::Node serializedNode = node->serialize();
    std::string uuid = node->uuid();
    AGBasicUndoAction *action = new AGBasicUndoAction(
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

AGUndoAction *AGUndoAction::createConnectionUndoAction(AGConnection *connection)
{
    AGDocument::Connection serializedConnection = connection->serialize();
    std::string uuid = connection->uuid();
    AGBasicUndoAction *action = new AGBasicUndoAction(
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

AGUndoAction *AGUndoAction::deleteConnectionUndoAction(AGConnection *connection)
{
    AGDocument::Connection serializedConnection = connection->serialize();
    std::string uuid = connection->uuid();
    AGBasicUndoAction *action = new AGBasicUndoAction(
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


//------------------------------------------------------------------------------
// ### AGBasicUndoAction ###
//------------------------------------------------------------------------------
#pragma mark - AGBasicUndoAction

AGBasicUndoAction::AGBasicUndoAction(const std::string &title,
                                     std::function<void ()> _undo,
                                     std::function<void ()> _redo)
: AGUndoAction(title), m_undo(_undo), m_redo(_redo)
{ }

void AGBasicUndoAction::undo()
{
    m_undo();
}

void AGBasicUndoAction::redo()
{
    m_redo();
}

//------------------------------------------------------------------------------
// ### AGUndoManager ###
//------------------------------------------------------------------------------
#pragma mark - AGUndoManager

AGUndoManager &AGUndoManager::instance()
{
    static AGUndoManager s_undoManager;
    return s_undoManager;
}
    
AGUndoManager::AGUndoManager()
{ }

AGUndoManager::~AGUndoManager()
{ }

void AGUndoManager::pushUndoAction(AGUndoAction *action)
{
    m_undo.push_back(action);
    
    while(m_undo.size() > AG_MAX_UNDO)
    {
        delete m_undo.front();
        m_undo.pop_front();
    }
    
    for(auto action : m_redo)
        delete action;
    m_redo.clear();
}

void AGUndoManager::undoLast()
{
    if(m_undo.size())
    {
        AGUndoAction *action = m_undo.back();
        m_undo.pop_back();
        action->undo();
        m_redo.push_back(action);
    }
}

void AGUndoManager::redoLast()
{
    if(m_redo.size())
    {
        AGUndoAction *action = m_redo.back();
        m_redo.pop_back();
        action->redo();
        m_undo.push_back(action);
    }
}

bool AGUndoManager::hasUndo()
{
    return m_undo.size() > 0;
}

bool AGUndoManager::hasRedo()
{
    return m_redo.size() > 0;
}

std::string AGUndoManager::undoItemTitle()
{
    if(m_undo.size())
        return m_undo.back()->title();
    else
        return "";
}

std::string AGUndoManager::redoItemTitle()
{
    if(m_redo.size())
        return m_redo.back()->title();
    else
        return "";
}

