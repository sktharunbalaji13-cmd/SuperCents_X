#ifndef __I_TRADE_STATE_PROVIDER_MQH__
#define __I_TRADE_STATE_PROVIDER_MQH__

class ITradeStateProvider
{
public:
    virtual ~ITradeStateProvider() {}

    virtual int      GetBarsSinceLastTrade() = 0;
    virtual bool     HasOpenPosition() = 0;
    virtual datetime GetLastTradeTime() = 0;
    virtual string   GetName() = 0;
};

#endif