//
//  AGNetClient.h
//  Auraglyph
//
//  Created by Spencer Salazar on 11/24/20.
//  Copyright © 2020 Spencer Salazar. All rights reserved.
//

#pragma once

#include <string>
#include <vector>
#include <list>
#include <memory>

namespace Geoglyph {

struct Session
{
    struct Id { std::string _id; };
    
    Id _id;
    std::string name;
};

struct Error
{
    enum Code
    {
        NO_ERROR = 0,
        GENERAL_ERROR,
        SOCKET_ERROR,
    };
    
    Error() : code(Code::NO_ERROR) { }
    
    Error(Code code_, const std::string& detail_) : code(Code::NO_ERROR), detail(detail_) { }

    Code code;
    std::string detail;
    
    operator bool() const { return code != Code::NO_ERROR; }
};

struct Action
{
    std::string json_;
};

class Client
{
public:
    Client();
    ~Client();

    void setName(const std::string& name);
    const std::string& name();
    
    void listSessions();
    
    void join(const Session::Id& _id);
    void leave();
    
    void broadcast(const Action& msg);
    
    struct Listener
    {
    public:
        void errorOccurred(const Error& err) { }
        
        void listedSessions(const std::vector<Session>& sessions) { }
        
        void joinedSession(const Session::Id& sessionId) { }
        void leftSession(const Session::Id& sessionId) { }
        void receivedAction(const Session::Id& sessionId, const Action& msg) { }
    };
    
    void addListener(Listener* listener);
    void removeListener(Listener* listener);

private:
    
    void _sendHi();
    
    std::string mName;
    bool mNeedsToSendHi { true };
    bool mInSession { false };

    class impl;
    
    std::unique_ptr<impl> mImpl;
    
    std::list<Listener *> mListeners;
};

}
