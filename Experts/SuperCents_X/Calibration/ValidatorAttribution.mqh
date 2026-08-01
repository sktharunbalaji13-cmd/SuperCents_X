//+------------------------------------------------------------------+
//|                                      ValidatorAttribution.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Leave-one-out attribution: for each validator, replay the decision
//  stream with that validator forced to PASS and measure the delta on
//  expectancy / profit factor / win rate vs the locked baseline.
//
//  A positive delta for a FAIL-heavy validator means it currently blocks
//  profitable trades (candidate for weakening); a negative delta means it
//  protects the P&L (candidate for strengthening).
//+------------------------------------------------------------------+
#ifndef __VALIDATOR_ATTRIBUTION_MQH__
#define __VALIDATOR_ATTRIBUTION_MQH__

#include "../Telemetry/TelemetryTypes.mqh"
#include "CalibrationMetrics.mqh"
#include "../Core/Logger.mqh"

#define ATTR_MAX_ROWS      20000
#define ATTR_MAX_VALIDATORS 12

struct AttributionResult
{
    string     validator;
    int        gateFailCount;   // times it failed while others passed
    TradeStats baselineStats;   // locked config
    TradeStats ablationStats;   // with this validator forced to PASS
    double     deltaExpectancy;
    double     deltaProfitFactor;
    double     deltaWinRate;
    double     deltaTrades;     // settled trade count delta
    double     pValue;          // Welch t-test: ablation vs baseline
    bool       recommendWeaken; // blocks money: positive expectancy delta
    bool       recommendStrengthen; // protects P&L: negative expectancy delta

    AttributionResult(void)
        : validator("")
        , gateFailCount(0)
        , deltaExpectancy(0.0)
        , deltaProfitFactor(0.0)
        , deltaWinRate(0.0)
        , deltaTrades(0.0)
        , pValue(1.0)
        , recommendWeaken(false)
        , recommendStrengthen(false)
    {}
};

class CValidatorAttribution
{
public:
    CValidatorAttribution(void)
        : m_logger(MODULE_UNKNOWN, "ValidatorAttribution")
        , m_count(0)
    {}

    void Load(TelemetryRow &rows[], int count)
    {
        m_count = (count > ATTR_MAX_ROWS) ? ATTR_MAX_ROWS : count;
        ArrayResize(m_rows, m_count);
        for(int i = 0; i < m_count; i++)
            m_rows[i] = rows[i];
    }

    //--- Baseline = current config (stored confidence threshold).
    //    Analyzes every validator that appears in the dataset.
    int Analyze(double threshold, AttributionResult &results[])
    {
        //--- Collect the distinct validator names in dataset order.
        string names[ATTR_MAX_VALIDATORS];
        int nNames = 0;
        for(int i = 0; i < m_count && nNames < ATTR_MAX_VALIDATORS; i++)
        {
            for(int v = 0; v < m_rows[i].validatorCount; v++)
            {
                string nm = m_rows[i].validators[v].name;
                if(nm == "ConfluenceValidator")
                    continue;
                bool seen = false;
                for(int k = 0; k < nNames; k++)
                {
                    if(names[k] == nm)
                    {
                        seen = true;
                        break;
                    }
                }
                if(!seen)
                    names[nNames++] = nm;
            }
        }

        //--- Baseline stats under the locked config.
        bool baseEligible[];
        ArrayResize(baseEligible, m_count);
        for(int i = 0; i < m_count; i++)
            baseEligible[i] = m_rows[i].ReplayDecision(threshold);
        TradeStats baseline;
        CalibrationComputeStats(m_rows, baseEligible, m_count, baseline);

        //--- Ablation per validator.
        for(int k = 0; k < nNames; k++)
        {
            AttributionResult r;
            r.validator = names[k];

            bool eligible[];
            ArrayResize(eligible, m_count);
            for(int i = 0; i < m_count; i++)
            {
                eligible[i] = CalibrationReplayWithout(m_rows[i], threshold, names[k]);
                if(eligible[i])
                {
                    //--- Count how often this validator failed while the rest passed.
                    if(m_rows[i].GetValidatorResult(names[k]) == FILTER_FAIL)
                        r.gateFailCount++;
                }
            }

            CalibrationComputeStats(m_rows, eligible, m_count, r.ablationStats);
            r.baselineStats = baseline;

            r.deltaExpectancy = r.ablationStats.expectancy - baseline.expectancy;
            r.deltaProfitFactor = r.ablationStats.profitFactor - baseline.profitFactor;
            r.deltaWinRate = r.ablationStats.winRate - baseline.winRate;
            r.deltaTrades = r.ablationStats.trades - baseline.trades;

            r.pValue = WelchAblation(threshold, names[k], baseline.trades);

            //--- Policy: only recommend when the delta is material and significant.
            r.recommendWeaken =
                r.deltaExpectancy > 0.005 &&
                r.pValue < 0.05;
            r.recommendStrengthen =
                r.deltaExpectancy < -0.005 &&
                r.pValue < 0.05;

            results[k] = r;
        }

        return nNames;
    }

private:
    //--- Welch test: ablation group (validator removed) vs baseline group.
    double WelchAblation(double threshold, const string skip, int baselineTrades)
    {
        if(baselineTrades < 2)
            return 1.0;

        double a[];
        double b[];
        ArrayResize(a, m_count);
        ArrayResize(b, baselineTrades);

        int na = 0;
        int nb = 0;
        for(int i = 0; i < m_count; i++)
        {
            if(m_rows[i].outcome == (int)TELEMETRY_OUTCOME_UNKNOWN)
                continue;
            if(CalibrationReplayWithout(m_rows[i], threshold, skip) && na < m_count)
                a[na++] = m_rows[i].rMultiple;
            if(m_rows[i].ReplayDecision(threshold) && nb < baselineTrades)
                b[nb++] = m_rows[i].rMultiple;
        }
        return CalibrationWelchPValue(a, na, b, nb);
    }

    CLogger     m_logger;
    int          m_count;
    TelemetryRow m_rows[];
};

#endif


