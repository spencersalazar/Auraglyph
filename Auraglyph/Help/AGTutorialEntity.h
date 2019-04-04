//
//  AGTutorialEntity.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/3/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

/** Data model for tutorial:
 - Environment: persists data throughout the tutorial
 - Entity: Base class, configured through environment + parameters
 - Action: Display or activate sound in the tutorial
 - Condition: Evaluate tutorial actions
 - Step: Combine actions + conditions
 */

#pragma once

#include "Variant.h"
#include "AGRenderObject.h"
#include "AGActivityManager.h"

#include <string>
#include <map>

class AGViewController_;

#pragma mark AGTutorialEnvironment

/** Used to store and fetch information about the environment in which a
 tutorial is run, e.g. state that may change from instance to instance. For
 example, the UUIDs of nodes can be stored and then accessed later to check the
 state of that particular node. A tutorial environment is persistent throughout
 the length of a tutorial.
 */
class AGTutorialEnvironment
{
public:
    /** */
    AGTutorialEnvironment(AGViewController_ *viewController);
    
    /** */
    AGViewController_ *viewController();
    
    /** Store a variable in the environment. */
    void store(const std::string &name, const Variant &variable);
    
    /** Fetch a variable from the environment. */
    const Variant &fetch(const std::string &name, const Variant &variable);
    
private:
    /** */
    AGViewController_ *m_viewController = nullptr;
    /** Map of named variables in this environment. */
    std::map<std::string, Variant> m_variables;
};

#pragma mark AGTutorialEntity

/** Base class for tutorial-based entities. Captures parameters and a
 tutorial environment, is "prepared" right before it is engaged, and is
 "finalized" right after it is engaged.
 
 "Finalize" events are used to store information about the entity for future
 use by other entities, e.g. the position of a user action.
 
 "Prepare" events are used to set up the tutorial step based on parameters or
 variables from the environment, e.g. to position a graphical element based on
 previous user activity.
 
 Base classes include
 - AGTutorialAction, a small atomic action such as displaying text or graphics
 - AGTutorialCondition, which awaits a certain condition to advance to another
 tutorial step
 - AGTutorialStep, a discrete tutorial "step" comprising one or more actions
 and one more conditions for moving to successive tutorial steps
 */
class AGTutorialEntity
{
public:
    /** Constructor */
    AGTutorialEntity(const map<std::string, Variant> &parameters,
                     std::function<void (AGTutorialEnvironment &env)> onPrepare = [](AGTutorialEnvironment &env){ },
                     std::function<void (AGTutorialEnvironment &env)> onFinalize = [](AGTutorialEnvironment &env){ });
    /** Virtual destructor */
    virtual ~AGTutorialEntity();
    
    /** Prepare the internal state of tutorial step, reading any variables
     necessary from the specified environment.
     */
    void prepare(AGTutorialEnvironment &environment);
    
    /** Finalize the tutorial step, storing any variables in the environment
     that may be accessed later.
     */
    void finalize(AGTutorialEnvironment &environment);
    
protected:
    /** Get parameter for this entity with specified name. */
    Variant getParameter(const std::string &name, Variant defaultValue = Variant());
    
    /** Override to make subclass-specific set up when preparing this entity
     */
    virtual void prepareInternal(AGTutorialEnvironment &environment);
    /** Override to make subclass-specific set up when finalizing this entity
     */
    virtual void finalizeInternal(AGTutorialEnvironment &environment);
    
private:
    
    map<std::string, Variant> m_parameters;
    std::function<void (AGTutorialEnvironment &env)> m_onPrepare;
    std::function<void (AGTutorialEnvironment &env)> m_onFinalize;
};

#pragma mark AGTutorialAction

/** Tutorial action, e.g. displaying graphics or text, creating a node, etc.
 */
class AGTutorialAction : public AGTutorialEntity, public AGRenderObject
{
public:
    /** Constructor */
    AGTutorialAction(const map<std::string, Variant> &parameters = { },
                     std::function<void (AGTutorialEnvironment &env)> onPrepare = [](AGTutorialEnvironment &env){ },
                     std::function<void (AGTutorialEnvironment &env)> onFinalize = [](AGTutorialEnvironment &env){ });
    
    /** Whether or not the action can be continued from, i.e. execute the next
     action.
     */
    virtual bool canContinue() = 0;
    
    /** Whether or not the action is complete, i.e. can be removed from the
     graphics pipeline.
     */
    virtual bool isCompleted() = 0;
    
    /** Render fixed */
    bool renderFixed() override { return true; }
};

#pragma mark AGTutorialCondition

/** Tutorial condition. A tutorial condition associated with a tutorial step
 is checked periodically to see if the step is complete.
 
 E.g. if a certain time has elapsed, continue anyways, or wait for a particular
 user activity.
 */
class AGTutorialCondition : public AGTutorialEntity, public AGActivityListener
{
public:
    /** Constructor */
    AGTutorialCondition(const map<std::string, Variant> &parameters = { },
                        std::function<void (AGTutorialEnvironment &env)> onPrepare = [](AGTutorialEnvironment &env){ },
                        std::function<void (AGTutorialEnvironment &env)> onFinalize = [](AGTutorialEnvironment &env){ });
    
    // enum of possible condition status
    enum Status
    {
        STATUS_INCOMPLETE = 0, // the condition is not yet complete and no action should be taken
        STATUS_CONTINUE, // the condition is complete, continue to the next tutorial step
        STATUS_RESTART, // the condition is incomplete and the tutorial step should be restarted
    };
    
    /** */
    virtual Status getStatus() = 0;
    /** */
    void activityOccurred(AGActivity *activity) override { }
};

#pragma mark AGTutorialStep

/** Base class for a single "step" in a tutorial.
 Combines zero or more "actions" (e.g., display of text/graphics) with zero or
 more conditions for proceeding to the next action.
 
 By default, if no condition is provided, the step will continue when all of the
 actions have finished.
 */
class AGTutorialStep : public AGTutorialEntity, public AGRenderObject, public AGActivityListener
{
public:
    /** Constructor with any number of actions / conditions*/
    AGTutorialStep(const std::list<AGTutorialAction*> &actions,
                   const std::list<AGTutorialCondition*> &conditions,
                   const std::map<std::string, Variant> &parameters = { });
    /** Constructor, taking only one action and no conditions
     (will complete immediately)
     */
    AGTutorialStep(AGTutorialAction *action,
                   const std::map<std::string, Variant> &parameters = { });

    ~AGTutorialStep();
    
    bool canContinue();
    
    bool isCompleted();
    
    void update(float t, float dt) override;
    
    void render() override;
    
    void activityOccurred(AGActivity *activity) override;
    
private:
    /** Check if any conditions have been triggered */
    void _checkConditions();
    
    /** Override to make subclass-specific set up when preparing this entity
     */
    void prepareInternal(AGTutorialEnvironment &environment) override;
    
    /** Override to make subclass-specific set up when finalizing this entity
     */
    void finalizeInternal(AGTutorialEnvironment &environment) override;
    
    AGTutorialEnvironment *m_environment = nullptr;
    
    list<AGTutorialAction*> m_actions;
    list<AGTutorialAction*>::iterator m_currentAction;
    list<AGTutorialAction*> m_activeActions;
    
    list<AGTutorialCondition*> m_conditions;
    AGTutorialCondition *m_completedCondition = nullptr;
    AGTutorialCondition::Status m_conditionStatus = AGTutorialCondition::STATUS_INCOMPLETE;
};

