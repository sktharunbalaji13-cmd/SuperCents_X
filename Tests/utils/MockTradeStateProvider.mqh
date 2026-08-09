#ifndef __MOCK_TRADE_STATE_PROVIDER_MQH__
#define __MOCK_TRADE_STATE_PROVIDER_MQH__

#include "../../Entry/Validators/ITradeStateProvider.mqh"

class CMockTradeStateProvider : public ITradeStateProvider
{
private:
    int      m_barsSince;
    bool     m_hasPosition;
    datetime m_lastTradeTime;
    string   m_name;

public:
    CMockTradeStateProvider(string name = "MockTradeState")
        : m_barsSince(999)
        , m_hasPosition(false)
        , m_lastTradeTime(0)
        , m_name(name)
    {}

    void SetBarsSinceLastTrade(int v) { m_barsSince = v; }
    void SetHasOpenPosition(bool v) { m_hasPosition = v; }
    void SetLastTradeTime(datetime v) { m_lastTradeTime = v; }

    virtual int      GetBarsSinceLastTrade() { return m_barsSince; }
    virtual bool     HasOpenPosition()       { return m_hasPosition; }
    virtual datetime GetLastTradeTime()      { return m_lastTradeTime; }
    virtual string   GetName()               { return m_name; }
};

#endif