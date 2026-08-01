#ifndef __C_SHADOW_TRADE_STATE_PROVIDER_MQH__
#define __C_SHADOW_TRADE_STATE_PROVIDER_MQH__

#include "Validators/ITradeStateProvider.mqh"

class CShadowTradeStateProvider : public ITradeStateProvider
{
public:
    virtual int      GetBarsSinceLastTrade() { return 999999; }
    virtual bool     HasOpenPosition()       { return false; }
    virtual datetime GetLastTradeTime()      { return 0; }
    virtual string   GetName()               { return "ShadowTradeState"; }
};

#endif