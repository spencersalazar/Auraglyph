//
//  AGNetClient.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 11/24/20.
//  Copyright © 2020 Spencer Salazar. All rights reserved.
//

#include "Geoglyph.h"

#include <netdb.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include "json.hpp"
using json = nlohmann::json;

namespace Geoglyph {

class Client::impl
{
public:
    impl() { }
    
    ~impl()
    {
        disconnect();
    }
    
    bool isConnected()
    {
        return sockfd != -1;
    }
    
    Error connectIfNeeded()
    {
        if (isConnected()) {
            return { };
        }
        
        const char* host = "localhost";
        int port = 1234;
        
        struct hostent *he;
        struct sockaddr_in remote_addr;
        
        he = gethostbyname(host);
        if (he == nullptr) {
            return { Error::Code::SOCKET_ERROR, "error getting hostname" };
        }

        sockfd = socket(AF_INET, SOCK_STREAM, 0);
        if (sockfd == -1) {
            return { Error::Code::SOCKET_ERROR, "error creating socket" };
        }

        bzero(&remote_addr, sizeof(sockaddr_in));
        remote_addr.sin_family = AF_INET;
        remote_addr.sin_port = htons(port);
        remote_addr.sin_addr = *((struct in_addr *) he->h_addr);

        int result = connect(sockfd, (struct sockaddr *)&remote_addr, sizeof(struct sockaddr));
        if (result == -1) {
            return { Error::Code::SOCKET_ERROR, "error calling connect" };
        }
        
        return { };
    }
    
    Error send(const json& json_)
    {
        std::string jsonStr = json_.dump();
        return send(jsonStr.c_str(), jsonStr.length());
    }
        
    Error send(const char* buffer, ssize_t length)
    {
        if (sockfd == -1) {
            return { Error::Code::SOCKET_ERROR, "not connected" };
        }
        
        ssize_t sent = 0;
        while (sent < length) {
            ssize_t result = ::send(sockfd, buffer+sent, length-sent, 0);
            
            if (result == -1) {
                return { Error::Code::SOCKET_ERROR, "error sending data" };
            }
            
            sent += result;
        }
        
        return { };
    }
    
    Error receive(json& json_)
    {
        if (sockfd == -1) {
            return { Error::Code::SOCKET_ERROR, "not connected" };
        }
        
        std::string msgBuffer;
        char recvBuffer[128];
        
        ssize_t numBytes = 0;
        do {
            numBytes = recv(sockfd, recvBuffer, sizeof(recvBuffer), 0);
            
            if (numBytes == -1) { return { Error::Code::SOCKET_ERROR, "error from recv" }; }
            
            msgBuffer.append(recvBuffer, numBytes);
        } while (strnstr(recvBuffer, "\r\n", numBytes) == nullptr);
        
        try {
            json_ = json::parse(msgBuffer);
        } catch (json::parse_error& e) {
            return { Error::Code::SOCKET_ERROR, std::string("failed to parse json: ") + e.what() };
        }
        
        return { };
    }
    
    void disconnect()
    {
        if (sockfd != -1) {
            close(sockfd);
            sockfd = -1;
        }
    }
    
    int sockfd = -1;
};


Client::Client()
: mImpl(new Client::impl())
{ }

Client::~Client()
{ }

void Client::setName(const std::string& name)
{
    mName = name;
}

const std::string& Client::name()
{
    return mName;
}

void Client::listSessions()
{
    mImpl->connectIfNeeded();
    
    json listCmd = {
        {"cmd", "list"},
    };
    
    auto err = mImpl->send(listCmd);
    if (err) {
        return;
    }
    
    json listResponse;
    
    do {
        err = mImpl->receive(listResponse);
        
        if (err) { return; }
    } while (listResponse["cmd"] != "list");
    
    std::vector<Session> sessions;
    
    try {
        for (auto sessionJson : listResponse.at("session")) {
            sessions.push_back({ sessionJson.at("id"), sessionJson.at("name") });
        }
    } catch (const json::exception& e) {
        // invalid json
        return;
    }
    
    for (auto listener : mListeners) {
        listener->listedSessions(sessions);
    }
}

void Client::_sendHi()
{
    json hiCmd = {
        {"cmd", "hi"},
        {"name", mName},
    };
    
    auto err = mImpl->send(hiCmd);
    
    if (err) { return; }

    mNeedsToSendHi = false;
}

void Client::join(const Session::Id& sessionId)
{
    mImpl->connectIfNeeded();
    
    if (mNeedsToSendHi) { _sendHi(); }
    
    json joinCmd = {
        {"cmd", "join"},
        {"session_id", sessionId._id},
    };
    
    auto err = mImpl->send(joinCmd);
    
    if (err) { return; }
    
    mInSession = true;
}

void Client::leave()
{
    if (mInSession) {
        
        json leaveCmd = {
            {"cmd", "leave"},
        };
        
        auto err = mImpl->send(leaveCmd);
        
        if (err) { return; }
        
        mInSession = false;
    }
}

void Client::broadcast(const Action& msg)
{
    if (mInSession) {
        json broadcastCmd = {
            {"cmd", "broadcast"},
            {"data", msg.json_ }
        };
        
        mImpl->send(broadcastCmd);
    }
}

void Client::addListener(Listener* listener)
{
    mListeners.push_back(listener);
}

void Client::removeListener(Listener* listener)
{
    mListeners.remove(listener);
}

}

