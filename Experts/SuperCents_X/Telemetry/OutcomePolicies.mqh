//+------------------------------------------------------------------+
//|                                         OutcomePolicies.mqh        |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Concrete exit policies:
//
//    FixedRR       — SL = slR x ATR, TP = tpR x ATR
//    ATR           — SL = slAtr x ATR, TP = tpAtr x ATR (independent)
//    Trailing      — FixedRR + trailing stop after trailActivationR x ATR
//    EntryResolver — SL/TP from the live entry pipeline (EntrySetupBuilder);
//                    falls back to FixedRR when no setup is available
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_OUTCOME_POLICIES_MQH__
#define __TELEMETRY_OUTCOME_POLICIES_MQH__

#include "IOutcomePolicy.mqh"
#include "../Entry/EntrySetupBuilder.mqh"
#include "../Confluence/ConfluenceEngine.mqh"

#define OUTCOME_ATR_PERIOD 14

class CFixedRRPolicy : public IOutcomePolicy
{
private:
    double m_slR;
    double m_tpR;
    double m_atrMult;
    int    m_atrPeriod;

public:
    CFixedRRPolicy(double slR = 1.0, double tpR = 2.0,
                   double atrMult = 1.0, int atrPeriod = OUTCOME_ATR_PERIOD)
        : m_slR(slR)
        , m_tpR(tpR)
        , m_atrMult(atrMult)
        , m_atrPeriod(atrPeriod)
    {}

    virtual string GetName() const { return "FixedRR"; }
    virtual string GetVersion() const { return "1"; }

    virtual bool ResolveExitLevels(const string symbol,
                                   ENUM_TIMEFRAMES timeframe,
                                   double entryPrice,
                                   ConfluenceDirection direction,
                                   int entryBarIndex,
                                   const double &open[],
                                   const double &high[],
                                   const double &low[],
                                   const double &close[],
                                   PolicyExitLevels &levels)
    {
        int size = ArraySize(high);
        double atr = OutcomePolicyATR(high, low, close, entryBarIndex, m_atrPeriod, size);
        double riskDistance = m_atrMult * atr;
        if(riskDistance <= 0.0 || entryPrice <= 0.0)
            return false;

        int dir = (direction == CONFLUENCE_BULLISH) ? 1 : -1;
        levels.valid = true;
        levels.riskDistance = riskDistance;
        levels.slPrice = entryPrice - dir * riskDistance * m_slR;
        levels.tpPrice = entryPrice + dir * riskDistance * m_tpR;
        levels.useTrailing = false;
        return true;
    }
};

class CATRPolicy : public IOutcomePolicy
{
private:
    double m_slAtr;
    double m_tpAtr;
    int    m_atrPeriod;

public:
    CATRPolicy(double slAtr = 1.5, double tpAtr = 3.0, int atrPeriod = OUTCOME_ATR_PERIOD)
        : m_slAtr(slAtr)
        , m_tpAtr(tpAtr)
        , m_atrPeriod(atrPeriod)
    {}

    virtual string GetName() const { return "ATR"; }
    virtual string GetVersion() const { return "1"; }

    virtual bool ResolveExitLevels(const string symbol,
                                   ENUM_TIMEFRAMES timeframe,
                                   double entryPrice,
                                   ConfluenceDirection direction,
                                   int entryBarIndex,
                                   const double &open[],
                                   const double &high[],
                                   const double &low[],
                                   const double &close[],
                                   PolicyExitLevels &levels)
    {
        int size = ArraySize(high);
        double atr = OutcomePolicyATR(high, low, close, entryBarIndex, m_atrPeriod, size);
        if(atr <= 0.0 || entryPrice <= 0.0)
            return false;

        int dir = (direction == CONFLUENCE_BULLISH) ? 1 : -1;
        levels.valid = true;
        levels.riskDistance = m_slAtr * atr;
        levels.slPrice = entryPrice - dir * m_slAtr * atr;
        levels.tpPrice = entryPrice + dir * m_tpAtr * atr;
        levels.useTrailing = false;
        return true;
    }
};

class CTrailingPolicy : public IOutcomePolicy
{
private:
    double m_slR;
    double m_tpR;
    double m_atrMult;
    double m_trailActivationR;
    double m_trailDistanceR;
    int    m_atrPeriod;

public:
    CTrailingPolicy(double slR = 1.0, double tpR = 2.0,
                    double atrMult = 1.0, int atrPeriod = OUTCOME_ATR_PERIOD,
                    double trailActivationR = 1.0, double trailDistanceR = 0.5)
        : m_slR(slR)
        , m_tpR(tpR)
        , m_atrMult(atrMult)
        , m_atrPeriod(atrPeriod)
        , m_trailActivationR(trailActivationR)
        , m_trailDistanceR(trailDistanceR)
    {}

    virtual string GetName() const { return "Trailing"; }
    virtual string GetVersion() const { return "1"; }

    virtual bool ResolveExitLevels(const string symbol,
                                   ENUM_TIMEFRAMES timeframe,
                                   double entryPrice,
                                   ConfluenceDirection direction,
                                   int entryBarIndex,
                                   const double &open[],
                                   const double &high[],
                                   const double &low[],
                                   const double &close[],
                                   PolicyExitLevels &levels)
    {
        int size = ArraySize(high);
        double atr = OutcomePolicyATR(high, low, close, entryBarIndex, m_atrPeriod, size);
        double riskDistance = m_atrMult * atr;
        if(riskDistance <= 0.0 || entryPrice <= 0.0)
            return false;

        int dir = (direction == CONFLUENCE_BULLISH) ? 1 : -1;
        levels.valid = true;
        levels.riskDistance = riskDistance;
        levels.slPrice = entryPrice - dir * riskDistance * m_slR;
        levels.tpPrice = entryPrice + dir * riskDistance * m_tpR;
        levels.useTrailing = true;
        levels.trailActivationPrice = entryPrice + dir * riskDistance * m_trailActivationR;
        levels.trailDistance = riskDistance * m_trailDistanceR;
        return true;
    }
};

//--- EntryResolver: uses the live entry pipeline SL/TP when a setup can be
//    built for the latest confluence signal; otherwise falls back to FixedRR.
class CEntryResolverPolicy : public IOutcomePolicy
{
private:
    CEntrySetupBuilder *m_builder;
    CConfluenceEngine  *m_confluence;
    double m_slR;
    double m_tpR;
    double m_atrMult;
    int    m_atrPeriod;

public:
    CEntryResolverPolicy(CEntrySetupBuilder *builder, CConfluenceEngine *confluence,
                         double slR = 1.0, double tpR = 2.0,
                         double atrMult = 1.0, int atrPeriod = OUTCOME_ATR_PERIOD)
        : m_builder(builder)
        , m_confluence(confluence)
        , m_slR(slR)
        , m_tpR(tpR)
        , m_atrMult(atrMult)
        , m_atrPeriod(atrPeriod)
    {}

    virtual string GetName() const { return "EntryResolver"; }
    virtual string GetVersion() const { return "1"; }

    virtual bool ResolveExitLevels(const string symbol,
                                   ENUM_TIMEFRAMES timeframe,
                                   double entryPrice,
                                   ConfluenceDirection direction,
                                   int entryBarIndex,
                                   const double &open[],
                                   const double &high[],
                                   const double &low[],
                                   const double &close[],
                                   PolicyExitLevels &levels)
    {
        if(m_builder != NULL && m_confluence != NULL)
        {
            int count = m_confluence.GetSignalCount();
            if(count > 0)
            {
                ConfluenceSignal signal;
                if(m_confluence.GetSignal(count - 1, signal))
                {
                    EntrySetup setup;
                    if(m_builder.Build(signal, setup) && setup.valid && setup.stopLoss != setup.entryPrice)
                    {
                        double risk = MathAbs(setup.entryPrice - setup.stopLoss);
                        if(risk > 0.0)
                        {
                            int dir = (setup.direction == TREND_BULLISH) ? 1 : -1;
                            levels.valid = true;
                            levels.riskDistance = risk;
                            levels.slPrice = setup.stopLoss;
                            levels.tpPrice = setup.takeProfit;
                            levels.useTrailing = false;
                            return true;
                        }
                    }
                }
            }
        }

        CFixedRRPolicy fallback(m_slR, m_tpR, m_atrMult, m_atrPeriod);
        return fallback.ResolveExitLevels(symbol, timeframe, entryPrice, direction,
                                          entryBarIndex, open, high, low, close, levels);
    }
};

#endif
