#ifndef __VALIDATION_EVENT_BUS_MQH__
#define __VALIDATION_EVENT_BUS_MQH__

#include "ValidationTypes.mqh"
#include "../Core/Logger.mqh"

#define MAX_VALIDATION_SUBSCRIBERS 16
#define MAX_VALIDATION_EVENT_TYPES 4

class CValidationEventHandler
{
public:
    virtual void OnEvent(const ValidationEventData &data) {}
};

class CValidationEventBus
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    CValidationEventHandler *m_subscribers[MAX_VALIDATION_EVENT_TYPES][MAX_VALIDATION_SUBSCRIBERS];
    int                      m_subscriberCount[MAX_VALIDATION_EVENT_TYPES];

public:
    CValidationEventBus(void);
    ~CValidationEventBus(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool Subscribe(int eventType, CValidationEventHandler *handler);
    bool Unsubscribe(int eventType, CValidationEventHandler *handler);
    int  Publish(int eventType, const ValidationEventData &data);
};

CValidationEventBus::CValidationEventBus(void)
    : m_logger(MODULE_UNKNOWN, "ValidationEventBus")
    , m_isInitialized(false)
{
    for(int t = 0; t < MAX_VALIDATION_EVENT_TYPES; t++)
        m_subscriberCount[t] = 0;

    for(int t = 0; t < MAX_VALIDATION_EVENT_TYPES; t++)
        for(int s = 0; s < MAX_VALIDATION_SUBSCRIBERS; s++)
            m_subscribers[t][s] = NULL;
}

CValidationEventBus::~CValidationEventBus(void)
{
    Shutdown();
}

bool CValidationEventBus::Init(void)
{
    m_logger.LogInfo("Initializing ValidationEventBus...");
    m_isInitialized = true;
    m_logger.LogInfo("ValidationEventBus initialized");
    return true;
}

void CValidationEventBus::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    for(int t = 0; t < MAX_VALIDATION_EVENT_TYPES; t++)
    {
        m_subscriberCount[t] = 0;
        for(int s = 0; s < MAX_VALIDATION_SUBSCRIBERS; s++)
            m_subscribers[t][s] = NULL;
    }

    m_isInitialized = false;
    m_logger.LogInfo("ValidationEventBus shutdown complete");
}

bool CValidationEventBus::Subscribe(int eventType, CValidationEventHandler *handler)
{
    if(!m_isInitialized || handler == NULL)
        return false;

    if(eventType < 0 || eventType >= MAX_VALIDATION_EVENT_TYPES)
        return false;

    if(m_subscriberCount[eventType] >= MAX_VALIDATION_SUBSCRIBERS)
    {
        m_logger.LogWarn("Max subscribers reached for validation event type");
        return false;
    }

    for(int i = 0; i < m_subscriberCount[eventType]; i++)
    {
        if(m_subscribers[eventType][i] == handler)
            return true;
    }

    m_subscribers[eventType][m_subscriberCount[eventType]] = handler;
    m_subscriberCount[eventType]++;
    return true;
}

bool CValidationEventBus::Unsubscribe(int eventType, CValidationEventHandler *handler)
{
    if(!m_isInitialized || handler == NULL)
        return false;

    if(eventType < 0 || eventType >= MAX_VALIDATION_EVENT_TYPES)
        return false;

    for(int i = 0; i < m_subscriberCount[eventType]; i++)
    {
        if(m_subscribers[eventType][i] == handler)
        {
            for(int j = i; j < m_subscriberCount[eventType] - 1; j++)
                m_subscribers[eventType][j] = m_subscribers[eventType][j + 1];
            m_subscriberCount[eventType]--;
            m_subscribers[eventType][m_subscriberCount[eventType]] = NULL;
            return true;
        }
    }

    return false;
}

int CValidationEventBus::Publish(int eventType, const ValidationEventData &data)
{
    if(!m_isInitialized)
        return 0;

    if(eventType < 0 || eventType >= MAX_VALIDATION_EVENT_TYPES)
        return 0;

    int notified = 0;

    for(int i = 0; i < m_subscriberCount[eventType]; i++)
    {
        if(m_subscribers[eventType][i] != NULL)
        {
            m_subscribers[eventType][i].OnEvent(data);
            notified++;
        }
    }

    return notified;
}

#endif
