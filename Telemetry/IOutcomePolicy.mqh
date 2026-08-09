//+------------------------------------------------------------------+
//|                                            IOutcomePolicy.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Pluggable exit assumption for the forward outcome simulator.
//  A policy answers one question: given an entry, where are the SL/TP
//  levels (and optional trailing rules)?
//
//  IMPORTANT: policy name + version are part of the configuration
//  fingerprint. Changing exit semantics (intrabar precedence, gap
//  handling, tie-breaking, partial fills) MUST bump the version so
//  historical datasets are never mixed with new ones.
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_I_OUTCOME_POLICY_MQH__
#define __TELEMETRY_I_OUTCOME_POLICY_MQH__

#include "TelemetryTypes.mqh"

//--- Selectable outcome TP mode for the forward outcome simulator
//    (ED01-D prerequisite, frozen docs/Sprint20_ED01D_PreRequisite.md,
//    2026-08-09). Default = FixedRR so default behavior stays byte-identical
//    to the frozen B8 baseline; the opposing-liquidity arm is selectable
//    per run and recorded in the simulator manifest.
enum ENUM_OUTCOME_TP_MODE
{
    OUTCOME_TP_FIXED_RR = 0,        // legacy FixedRR (default; byte-identical vs B8)
    OUTCOME_TP_OPPOSING_LIQUIDITY   // DD04 TARGET_OPPOSING_LIQUIDITY via TargetResolver
};

//--- Exit levels produced by a policy for one simulated trade.
struct PolicyExitLevels
{
    bool   valid;
    double slPrice;
    double tpPrice;
    double riskDistance;          // price distance of 1R (for rMultiple)

    bool   useTrailing;
    double trailActivationPrice;  // trailing engages when price crosses this
    double trailDistance;         // SL ratchets behind the extreme price

    PolicyExitLevels(void)
        : valid(false)
        , slPrice(0.0)
        , tpPrice(0.0)
        , riskDistance(0.0)
        , useTrailing(false)
        , trailActivationPrice(0.0)
        , trailDistance(0.0)
    {}
};

class IOutcomePolicy
{
public:
    virtual ~IOutcomePolicy() {}

    virtual string GetName() const = 0;      // e.g. "FixedRR"
    virtual string GetVersion() const = 0;   // e.g. "1"  — bump on any semantics change

    //--- Resolve SL/TP (and optional trailing) for a long/short entry.
    //    Arrays are as-series (index 0 = newest bar). entryBarIndex is the
    //    bar at whose open the trade is entered.
    virtual bool ResolveExitLevels(const string symbol,
                                   ENUM_TIMEFRAMES timeframe,
                                   double entryPrice,
                                   ConfluenceDirection direction,
                                   int entryBarIndex,
                                   const double &open[],
                                   const double &high[],
                                   const double &low[],
                                   const double &close[],
                                   PolicyExitLevels &levels) = 0;

    //--- "Name@Version" for the configuration fingerprint.
    string GetFingerprintToken(void) const
    {
        return GetName() + "@" + GetVersion();
    }
};

//--- Shared ATR helper (as-series arrays: older bars have higher indexes).
double OutcomePolicyATR(const double &high[], const double &low[], const double &close[],
                        int entryBarIndex, int period, int size)
{
    if(size <= 1 || entryBarIndex < 0 || entryBarIndex >= size)
        return 0.0;

    int count = 0;
    double sum = 0.0;
    for(int i = entryBarIndex; i < size && count < period; i++)
    {
        if(i + 1 >= size)
            break;
        double tr = high[i] - low[i];
        double hc = MathAbs(high[i] - close[i + 1]);
        double lc = MathAbs(low[i] - close[i + 1]);
        if(hc > tr) tr = hc;
        if(lc > tr) tr = lc;
        sum += tr;
        count++;
    }
    if(count == 0)
        return 0.0;
    return sum / (double)count;
}

#endif
