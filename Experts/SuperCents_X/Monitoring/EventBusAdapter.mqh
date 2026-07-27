//+------------------------------------------------------------------+
//|                                        EventBusAdapter.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __MONITORING_EVENT_BUS_ADAPTER_MQH__
#define __MONITORING_EVENT_BUS_ADAPTER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "MonitoringTypes.mqh"

#define MAX_EVENT_SUBSCRIBERS 16
#define MAX_EVENT_TYPES 8

class CEventHandler
{
public:
    virtual void HandleEvent(const EventData &data) {}
};

class CEventBusAdapter
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    CEventHandler *m_subscribers[MAX_EVENT_TYPES][MAX_EVENT_SUBSCRIBERS];
    int            m_subscriberCount[MAX_EVENT_TYPES];

    int EventTypeIndex(ENUM_EVENT_TYPE eventType) const
    {
        return (int)eventType;
    }

public:
    CEventBusAdapter(void);
    ~CEventBusAdapter(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool Subscribe(ENUM_EVENT_TYPE eventType, CEventHandler *handler);
    bool Unsubscribe(ENUM_EVENT_TYPE eventType, CEventHandler *handler);
    void Publish(const EventData &data);
};

CEventBusAdapter::CEventBusAdapter(void)
    : m_logger(MODULE_EVENT_BUS, "EventBus")
    , m_isInitialized(false)
{
    for(int t = 0; t < MAX_EVENT_TYPES; t++)
        m_subscriberCount[t] = 0;

    for(int t = 0; t < MAX_EVENT_TYPES; t++)
        for(int s = 0; s < MAX_EVENT_SUBSCRIBERS; s++)
            m_subscribers[t][s] = NULL;
}

CEventBusAdapter::~CEventBusAdapter(void)
{
    Shutdown();
}

bool CEventBusAdapter::Init(void)
{
    m_logger.LogInfo("Initializing EventBus...");
    m_isInitialized = true;
    m_logger.LogInfo("EventBus initialized");
    return true;
}

void CEventBusAdapter::Update(void)
{
}

void CEventBusAdapter::Shutdown(void)
{
    m_logger.LogInfo("Shutting down EventBus...");

    for(int t = 0; t < MAX_EVENT_TYPES; t++)
    {
        m_subscriberCount[t] = 0;
        for(int s = 0; s < MAX_EVENT_SUBSCRIBERS; s++)
            m_subscribers[t][s] = NULL;
    }

    m_isInitialized = false;
    m_logger.LogInfo("EventBus shutdown complete");
}

bool CEventBusAdapter::Subscribe(ENUM_EVENT_TYPE eventType, CEventHandler *handler)
{
    if(!m_isInitialized || handler == NULL)
        return false;

    int idx = EventTypeIndex(eventType);
    if(idx < 0 || idx >= MAX_EVENT_TYPES)
        return false;

    if(m_subscriberCount[idx] >= MAX_EVENT_SUBSCRIBERS)
    {
        m_logger.LogWarn("Max subscribers reached for event type");
        return false;
    }

    for(int i = 0; i < m_subscriberCount[idx]; i++)
    {
        if(m_subscribers[idx][i] == handler)
            return true;
    }

    m_subscribers[idx][m_subscriberCount[idx]] = handler;
    m_subscriberCount[idx]++;
    return true;
}

bool CEventBusAdapter::Unsubscribe(ENUM_EVENT_TYPE eventType, CEventHandler *handler)
{
    if(!m_isInitialized || handler == NULL)
        return false;

    int idx = EventTypeIndex(eventType);
    if(idx < 0 || idx >= MAX_EVENT_TYPES)
        return false;

    for(int i = 0; i < m_subscriberCount[idx]; i++)
    {
        if(m_subscribers[idx][i] == handler)
        {
            for(int j = i; j < m_subscriberCount[idx] - 1; j++)
                m_subscribers[idx][j] = m_subscribers[idx][j + 1];
            m_subscriberCount[idx]--;
            m_subscribers[idx][m_subscriberCount[idx]] = NULL;
            return true;
        }
    }
    return false;
}

void CEventBusAdapter::Publish(const EventData &data)
{
    if(!m_isInitialized)
        return;

    int idx = EventTypeIndex(data.eventType);
    if(idx < 0 || idx >= MAX_EVENT_TYPES)
        return;

    for(int i = 0; i < m_subscriberCount[idx]; i++)
    {
        if(m_subscribers[idx][i] != NULL)
            m_subscribers[idx][i].HandleEvent(data);
    }
}

#endif
