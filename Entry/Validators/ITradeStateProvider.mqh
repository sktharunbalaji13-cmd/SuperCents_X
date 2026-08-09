#ifndef __I_TRADE_STATE_PROVIDER_MQH__
#define __I_TRADE_STATE_PROVIDER_MQH__

//+------------------------------------------------------------------+
//| Trade state provider contract                                    |
//|                                                                  |
//| @frozen v3.0-provider-contract                                   |
//|                                                                  |
//| Contract rules (providers):                                      |
//|   - Providers SHALL retrieve account/trade state only.           |
//|   - Providers SHALL NOT contain business logic (cooldown         |
//|     thresholds, position sizing policy, session policy).         |
//|   - Validators SHALL NOT reach into MT5 APIs; they consume       |
//|     providers through this interface.                            |
//|                                                                  |
//| Semantics:                                                       |
//|   - GetBarsSinceLastTrade() returns the distance, in chart-time- |
//|     frame bars (PERIOD_CURRENT), since the last closed deal for  |
//|     the provider's symbol+magic. INT_MAX means "no trade ever".  |
//|   - HasOpenPosition() is true only for positions matching the    |
//|     provider's symbol+magic.                                     |
//|   - GetLastTradeTime() returns 0 when no matching deal exists.   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| @frozen v3.0-provider-contract: trade state provider.            |
//| Providers SHALL retrieve state only; no business logic inside.   |
//| Future changes MUST be additive (new virtuals with defaults).    |
//+------------------------------------------------------------------+
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
