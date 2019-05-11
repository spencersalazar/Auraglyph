//
//  AGActivities.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/9/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGActivity.h"
#include "AGGraphManager.h"
#include "AGGraph.h"
#include "AGAudioManager.h"
#include "AGAudioNode.h"
#include "AGConnection.h"

#include <string>

namespace AG {

namespace Activities {
    
    class EditParam : public AGUndoableActivity
    {
    public:
        EditParam(AGNode *node, int _port, float _oldValue, float _newValue)
        : AGUndoableActivity(AGActivity::EditParamActivityType, "Edit Param", [](){}, [](){}),
        nodeUUID(node->uuid()), port(_port), oldValue(_oldValue), newValue(_newValue)
        { }
        
        void undo() override
        {
            // undo
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(nodeUUID);
            if(node != nullptr)
                node->setEditPortValue(port, oldValue);
        }
        
        void redo() override
        {
            // redo
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(nodeUUID);
            if(node != nullptr)
                node->setEditPortValue(port, newValue);
        }
        
        const std::string nodeUUID;
        const int port;
        const float oldValue;
        const float newValue;
    };
    
    class DrawNode : public AGActivity
    {
    public:
        DrawNode(AGHandwritingRecognizerFigure _figure, const GLvertex3f &_position)
        : AGActivity(AGActivity::DrawNodeActivityType, "Draw Node"),
        figure(_figure), position(_position)
        { }
        
        const AGHandwritingRecognizerFigure figure;
        const GLvertex3f position;
    };

    class CreateNode : public AGUndoableActivity
    {
    public:
        CreateNode(AGNode *node)
        : AGUndoableActivity(AGActivity::CreateNodeActivityType, "Create Node", [](){}, [](){}),
        nodeUUID(node->uuid()), serializedNode(node->serialize()), isOutput(node->type() == "Output")
        { }
        
        void undo() override
        {
            // remove/delete the node
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(nodeUUID);
            node->removeFromTopLevel();
        }
        
        void redo() override
        {
            // re-create/re-add the node
            AGNode *node = AGNodeManager::createNode(serializedNode);
            AGGraphManager::instance().addNodeToTopLevel(node);
            if(isOutput)
            {
                AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
                outputNode->setOutputDestination(AGAudioManager_::instance().masterOut());
            }
        }

        const std::string nodeUUID;
        const AGDocument::Node serializedNode;
        const bool isOutput;
    };
    
    class MoveNode : public AGUndoableActivity
    {
    public:
        MoveNode(AGNode *node, const GLvertex3f &_oldPos, const GLvertex3f &_newPos)
        : AGUndoableActivity(AGActivity::MoveNodeActivityType, "Move Node", [](){}, [](){}),
        nodeUUID(node->uuid()), oldPos(_oldPos), newPos(_newPos)
        { }
        
        void undo() override
        {
            // move the node back
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(nodeUUID);
            node->setPosition(oldPos);
        }
        
        void redo() override
        {
            // move the node back
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(nodeUUID);
            node->setPosition(newPos);
        }
        
        const std::string nodeUUID;
        const GLvertex3f oldPos;
        const GLvertex3f newPos;
    };
    
    class DeleteNode : public AGUndoableActivity
    {
    public:
        DeleteNode(AGNode *node)
        : AGUndoableActivity(AGActivity::DeleteNodeActivityType, "Delete Node", [](){}, [](){}),
        nodeUUID(node->uuid()), serializedNode(node->serialize()), isOutput(node->type() == "Output")
        { }
        
        void undo() override
        {
            // re-create/re-add the node
            AGNode *node = AGNodeManager::createNode(serializedNode);
            AGGraphManager::instance().addNodeToTopLevel(node);
            if(isOutput)
            {
                AGAudioOutputNode *outputNode = dynamic_cast<AGAudioOutputNode *>(node);
                outputNode->setOutputDestination(AGAudioManager_::instance().masterOut());
            }
            
            // recreate connections
            for(auto connection : serializedNode.outbound)
                AGConnection::connect(connection);
            for(auto connection : serializedNode.inbound)
                AGConnection::connect(connection);
        }
        
        void redo() override
        {
            // remove/delete the node
            AGNode *node = AGGraphManager::instance().graph()->nodeWithUUID(nodeUUID);
            node->removeFromTopLevel();
        }

        const std::string nodeUUID;
        const AGDocument::Node serializedNode;
        const bool isOutput;
    };
    
    class CreateConnection : public AGUndoableActivity
    {
    public:
        CreateConnection(AGConnection *connection)
        : AGUndoableActivity(AGActivity::CreateConnectionActivityType, "Create Connection", [](){}, [](){}),
        serializedConnection(connection->serialize()), uuid(connection->uuid())
        { }
        
        void undo() override
        {
            // delete the connection
            AGConnection *connection = AGGraphManager::instance().graph()->connectionWithUUID(uuid);
            connection->removeFromTopLevel();
        }
        
        void redo() override
        {
            // recreate the connection
            AGConnection::connect(serializedConnection);
        }

        const AGDocument::Connection serializedConnection;
        const std::string uuid;
    };
    
    class DeleteConnection : public AGUndoableActivity
    {
    public:
        DeleteConnection(AGConnection *connection)
        : AGUndoableActivity(AGActivity::DeleteConnectionActivityType, "Delete Connection", [](){}, [](){}),
        serializedConnection(connection->serialize()), uuid(connection->uuid())
        { }
        
        void undo() override
        {
            // recreate the connection
            AGConnection::connect(serializedConnection);
        }
        
        void redo() override
        {
            // delete the connection
            AGConnection *connection = AGGraphManager::instance().graph()->connectionWithUUID(uuid);
            connection->removeFromTopLevel();
        }

        const AGDocument::Connection serializedConnection;
        const std::string uuid;
    };
    
    class OpenNodeEditor : public AGActivity
    {
    public:
        OpenNodeEditor(AGNode *node)
        : AGActivity(AGActivity::OpenNodeEditorActivityType, "Open Node Editor"),
        nodeUUID(node->uuid())
        { }
        
        const std::string nodeUUID;
    };
    
    class CloseNodeEditor : public AGActivity
    {
    public:
        CloseNodeEditor(AGNode *node)
        : AGActivity(AGActivity::CloseNodeEditorActivityType, "Close Node Editor"),
        nodeUUID(node->uuid())
        { }
        
        const std::string nodeUUID;
    };
} // namespace Activities
    
} // namespace AG


