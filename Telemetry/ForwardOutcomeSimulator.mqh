//+------------------------------------------------------------------+
//|                                      ForwardOutcomeSimulator.mqh   |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Simulates the forward outcome of a decision without risking capital.
//
//  Conventions (as-series arrays, index 0 = newest bar):
//    - The trade is entered at the OPEN of entryBarIndex.
//    - Bars after entry are scanned from entryBarIndex-1 (next newer bar)
//      up to maxHoldBars bars.
//    - Tie-breaking: when SL and TP are both touched within one bar the
//      SL (conservative) wins.  This is a policy-level assumption and is
//      versioned through the policy.
//    - Trailing: once price crosses the activation level the stop ratchets
//      behind the extreme price by the trail distance; it never moves back.
//    - Horizon exit: if neither SL nor TP is touched within maxHoldBars the
//      trade exits at the close of the last scanned bar.
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_FORWARD_OUTCOME_SIMULATOR_MQH__
#define __TELEMETRY_FORWARD_OUTCOME_SIMULATOR_MQH__

#include "IOutcomePolicy.mqh"
#include "OutcomePolicies.mqh"

#define OUTCOME_CLASSIFY_EPS 0.05   // |R| below this = BREAKEVEN

class CForwardOutcomeSimulator
{
private:
    IOutcomePolicy *m_policy;
    int             m_maxHoldBars;

    void Classify(double rMultiple, ENUM_EXIT_REASON exitReason, SimulatedOutcome &out) const
    {
        out.rMultiple = rMultiple;
        out.exitReason = exitReason;
        if(exitReason == EXIT_REASON_BREAKEVEN ||
           MathAbs(rMultiple) <= OUTCOME_CLASSIFY_EPS)
        {
            out.outcome = TELEMETRY_OUTCOME_BREAKEVEN;
        }
        else if(rMultiple > 0.0)
        {
            out.outcome = TELEMETRY_OUTCOME_WIN;
        }
        else
        {
            out.outcome = TELEMETRY_OUTCOME_LOSS;
        }
    }

public:
    CForwardOutcomeSimulator(void)
        : m_policy(NULL)
        , m_maxHoldBars(50)
    {}

    void SetPolicy(IOutcomePolicy *policy)     { m_policy = policy; }
    void SetMaxHoldBars(int bars)              { m_maxHoldBars = (bars > 1) ? bars : 50; }
    int  GetMaxHoldBars(void) const            { return m_maxHoldBars; }

    bool Simulate(const string symbol,
                  ENUM_TIMEFRAMES timeframe,
                  ConfluenceDirection direction,
                  int entryBarIndex,
                  const double &open[],
                  const double &high[],
                  const double &low[],
                  const double &close[],
                  SimulatedOutcome &out) const
    {
        out = SimulatedOutcome();

        int size = ArraySize(high);
        if(m_policy == NULL || size <= 1)
            return false;
        if(entryBarIndex < 0 || entryBarIndex >= size)
            return false;
        if(direction != CONFLUENCE_BULLISH && direction != CONFLUENCE_BEARISH)
            return false;

        double entryPrice = open[entryBarIndex];
        if(entryPrice <= 0.0)
            return false;

        PolicyExitLevels levels;
        if(!m_policy.ResolveExitLevels(symbol, timeframe, entryPrice, direction,
                                       entryBarIndex, open, high, low, close, levels))
            return false;
        if(!levels.valid || levels.riskDistance <= 0.0)
            return false;

        int dir = (direction == CONFLUENCE_BULLISH) ? 1 : -1;
        double sl = levels.slPrice;
        double tp = levels.tpPrice;

        //--- Scan newer bars (lower index) for up to maxHoldBars bars.
        int lastBar = entryBarIndex - 1;
        int minBar = entryBarIndex - m_maxHoldBars;
        if(minBar < 0)
            minBar = 0;

        double extreme = entryPrice;

        for(int b = lastBar; b >= minBar; b--)
        {
            //--- Trailing: ratchet the stop before checking this bar.
            if(levels.useTrailing)
            {
                if(dir > 0 && high[b] >= levels.trailActivationPrice)
                {
                    double candidate = high[b] - levels.trailDistance;
                    if(candidate > sl)
                        sl = candidate;
                }
                else if(dir < 0 && low[b] <= levels.trailActivationPrice)
                {
                    double candidate = low[b] + levels.trailDistance;
                    if(candidate < sl)
                        sl = candidate;
                }

                //--- Trailing stop ratchets before the bar is checked; the
                //    general SL test below uses the ratcheted level and the
                //    R-based classifier turns |R| <= eps into BREAKEVEN.
            }

            //--- Conservative tie-break: SL is checked before TP.
            if(dir > 0 && low[b] <= sl)
            {
                out.entryPrice = entryPrice;
                out.exitPrice = sl;
                out.barsHeld = (entryBarIndex - b) + 1;
                Classify((sl - entryPrice) / (dir * levels.riskDistance), EXIT_REASON_SL, out);
                return true;
            }
            if(dir < 0 && high[b] >= sl)
            {
                out.entryPrice = entryPrice;
                out.exitPrice = sl;
                out.barsHeld = (entryBarIndex - b) + 1;
                Classify((sl - entryPrice) / (dir * levels.riskDistance), EXIT_REASON_SL, out);
                return true;
            }

            if(dir > 0 && high[b] >= tp)
            {
                out.entryPrice = entryPrice;
                out.exitPrice = tp;
                out.barsHeld = (entryBarIndex - b) + 1;
                Classify((tp - entryPrice) / (dir * levels.riskDistance), EXIT_REASON_TP, out);
                return true;
            }
            if(dir < 0 && low[b] <= tp)
            {
                out.entryPrice = entryPrice;
                out.exitPrice = tp;
                out.barsHeld = (entryBarIndex - b) + 1;
                Classify((tp - entryPrice) / (dir * levels.riskDistance), EXIT_REASON_TP, out);
                return true;
            }

            if(dir > 0 && high[b] > extreme)
                extreme = high[b];
            if(dir < 0 && low[b] < extreme)
                extreme = low[b];
        }

        //--- Horizon exit at the close of the last scanned bar.
        out.entryPrice = entryPrice;
        out.exitPrice = close[minBar];
        out.barsHeld = (entryBarIndex - minBar) + 1;
        double rMultiple = (out.exitPrice - entryPrice) / (dir * levels.riskDistance);
        Classify(rMultiple, EXIT_REASON_HORIZON, out);
        return true;
    }
};

#endif
