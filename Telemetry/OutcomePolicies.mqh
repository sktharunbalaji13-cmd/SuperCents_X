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
#include "../Entry/TargetResolver.mqh"
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

    //--- ED01-E prerequisite: settle-time TP tier sweep. The replay
    //    simulator holds a pointer to this policy, so the tier is applied
    //    via a setter instead of reconstruction. Non-positive tiers are
    //    rejected (policy keeps the previous value; default 2.0R = B8).
    //    The tier does not enter the fingerprint (GetFingerprintToken
    //    stays "FixedRR@1") — arm identity is recorded in the manifest.
    void SetTpR(double tpR)
    {
        if(tpR > 0.0)
            m_tpR = tpR;
    }
    double GetTpR(void) const { return m_tpR; }

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

//--- Opposing-liquidity TP (ED01-D prerequisite, frozen 2026-08-09):
//    legacy FixedRR SL/TP with the DD04 TARGET_OPPOSING_LIQUIDITY arm.
//    When the source level is known and an ACTIVE opposite-class pool
//    exists, ResolveTakeProfit replaces the TP with the pool price;
//    otherwise the levels are BYTE-IDENTICAL to CFixedRRPolicy (the
//    frozen fallback — the replay outcome simulator can distinguish the
//    two arms, and never disturbs the legacy path when a pool is absent).
class COpposingLiquidityTPPolicy : public IOutcomePolicy
{
private:
    CLiquidityDetector *m_liqDetector;
    bool     m_hasLiquidity;
    int      m_liquidityId;
    double   m_slR;
    double   m_tpR;
    double   m_atrMult;
    int      m_atrPeriod;

public:
    COpposingLiquidityTPPolicy(CLiquidityDetector *liqDetector = NULL,
                               double slR = 1.0, double tpR = 2.0,
                               double atrMult = 1.0, int atrPeriod = OUTCOME_ATR_PERIOD)
        : m_liqDetector(liqDetector)
        , m_hasLiquidity(false)
        , m_liquidityId(-1)
        , m_slR(slR)
        , m_tpR(tpR)
        , m_atrMult(atrMult)
        , m_atrPeriod(atrPeriod)
    {}

    virtual string GetName() const { return "OpposingLiquidityTP"; }
    virtual string GetVersion() const { return "1"; }

    void SetLiquidityDetector(CLiquidityDetector *liqDetector) { m_liqDetector = liqDetector; }
    void SetSourceLiquidity(bool hasLiquidity, int liquidityId)
    {
        m_hasLiquidity = hasLiquidity;
        m_liquidityId = liquidityId;
    }

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

        //--- DD04 opposing-liquidity arm: replace the TP when an ACTIVE
        //    opposite-class pool resolves; otherwise the levels above are
        //    exactly the FixedRR values (byte-identical fallback).
        if(m_liqDetector != NULL && m_hasLiquidity && m_liquidityId >= 0)
        {
            TradeCandidate cand;
            cand.direction = direction;
            cand.hasLiquidity = true;
            cand.liquidityId = m_liquidityId;

            double tp = 0.0;
            string policyName = "";
            bool dummySR = false;
            if(ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, entryPrice,
                                 levels.slPrice, m_tpR, NULL, NULL, m_liqDetector,
                                 NULL, tp, policyName, dummySR))
            {
                if(StringCompare(policyName, "Opposing Liquidity") == 0)
                    levels.tpPrice = tp;
            }
        }
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
