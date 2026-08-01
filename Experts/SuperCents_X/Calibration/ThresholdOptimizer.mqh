//+------------------------------------------------------------------+
//|                                       ThresholdOptimizer.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Replays stored telemetry rows across a range of confidence
//  thresholds (default 0.40..0.80, step 0.05) and ranks each
//  threshold by expectancy, profit factor, win rate and drawdown.
//  Pure offline analysis â€” no engine access.
//+------------------------------------------------------------------+
#ifndef __THRESHOLD_OPTIMIZER_MQH__
#define __THRESHOLD_OPTIMIZER_MQH__

#include "../Telemetry/TelemetryTypes.mqh"
#include "../Telemetry/CalibrationDataset.mqh"
#include "CalibrationMetrics.mqh"
#include "../Core/Logger.mqh"

#define THRESHOLD_OPT_MAX_EVALS 32
#define THRESHOLD_OPT_MAX_ROWS  20000

struct ThresholdResult
{
    double     threshold;
    TradeStats stats;
    int        qualifiedSignals;   // all rows passing gate (incl. unsettled)
    int        settledTrades;      // rows with a simulated outcome
    double     pValueVsBaseline;   // Welch t-test vs baseline threshold
    bool       significant;        // p < 0.05 and |Î”expectancy| > epsilon

    ThresholdResult(void)
        : threshold(0.0)
        , qualifiedSignals(0)
        , settledTrades(0)
        , pValueVsBaseline(1.0)
        , significant(false)
    {}
};

class CThresholdOptimizer
{
public:
    CThresholdOptimizer(void)
        : m_logger(MODULE_UNKNOWN, "ThresholdOptimizer")
        , m_count(0)
        , m_lastCount(0)
    {}

    //--- Load rows for one fingerprint; returns count retained.
    int Load(CCalibrationDataset &dataset, ulong fingerprint)    {
        CCalibrationDataset filtered;
        if(!dataset.FilterByFingerprint(fingerprint, filtered))
        {
            m_count = 0;
            return 0;
        }

        int n = filtered.GetCount();
        if(n > THRESHOLD_OPT_MAX_ROWS)
            n = THRESHOLD_OPT_MAX_ROWS;
        ArrayResize(m_rows, n);
        m_count = 0;
        for(int i = 0; i < n; i++)
        {
            if(!filtered.GetRow(i, m_rows[i]))
                break;
            m_count++;
        }
        return m_count;
    }

    //--- Load pre-copied rows (already filtered to one fingerprint).
    void Load(TelemetryRow &rows[], int count)
    {
        int n = (count > THRESHOLD_OPT_MAX_ROWS) ? THRESHOLD_OPT_MAX_ROWS : count;
        ArrayResize(m_rows, n);
        m_count = 0;
        for(int i = 0; i < n; i++)
            m_rows[i] = rows[i];
        m_count = n;
    }

    //--- Run the threshold sweep.  Baseline = stats at threshold 0.60
    //    (or the supplied baseline).  Fills results[] (sorted by expectancy
    //    descending) and returns the number of results written.
    int Optimize(double minThreshold, double maxThreshold, double step,
                 double baselineThreshold, ThresholdResult &results[])
    {
        int n = 0;
        double baselineStats[1];
        TradeStats baseline;

        //--- Evaluate all thresholds first (keep natural order for ranking).
        for(double t = minThreshold; t <= maxThreshold + 0.0001 && n < THRESHOLD_OPT_MAX_EVALS; t += step)
        {
            ThresholdResult r;
            r.threshold = NormalizeThreshold(t);
            Evaluate(r);
            results[n++] = r;

            if(MathAbs(r.threshold - baselineThreshold) < 0.0001)
                baseline = r.stats;
        }

        //--- Significance vs baseline for every candidate.
        for(int i = 0; i < n; i++)
        {
            results[i].pValueVsBaseline = WelchTestVsBaseline(results[i], baseline);
            results[i].significant =
                results[i].pValueVsBaseline < 0.05 &&
                results[i].stats.expectancy > baseline.expectancy + 1e-9;
        }

        SortByExpectancy(results, n);
        m_lastCount = n;
        return n;
    }

    int LastCount(void) const { return m_lastCount; }

private:
    double NormalizeThreshold(double t)
    {
        return MathRound(t * 100.0) / 100.0;
    }

    //--- Evaluate one threshold: replay decisions, accumulate stats.
    void Evaluate(ThresholdResult &r)
    {
        bool eligible[];
        ArrayResize(eligible, m_count);

        r.qualifiedSignals = 0;
        for(int i = 0; i < m_count; i++)
        {
            eligible[i] = m_rows[i].ReplayDecision(r.threshold);
            if(eligible[i])
                r.qualifiedSignals++;
        }

        CalibrationComputeStats(m_rows, eligible, m_count, r.stats);
        r.settledTrades = r.stats.trades;
    }

    //--- Welch t-test of this threshold's rMultiples vs baseline's.
    double WelchTestVsBaseline(const ThresholdResult &cand, const TradeStats &baseline)
    {
        if(baseline.trades < 2 || cand.settledTrades < 2)
            return 1.0;

        double a[];
        double b[];
        ArrayResize(a, cand.settledTrades);
        ArrayResize(b, baseline.trades);

        int na = 0;
        int nb = 0;
        for(int i = 0; i < m_count; i++)
        {
            if(m_rows[i].outcome == (int)TELEMETRY_OUTCOME_UNKNOWN)
                continue;
            double rv = m_rows[i].rMultiple;
            if(m_rows[i].ReplayDecision(cand.threshold) && na < cand.settledTrades)
                a[na++] = rv;
            if(m_rows[i].ReplayDecision(0.60) && nb < baseline.trades)
                b[nb++] = rv;
        }
        return CalibrationWelchPValue(a, na, b, nb);
    }

    //--- Insertion sort by expectancy descending.
    void SortByExpectancy(ThresholdResult &results[], int n)
    {
        for(int i = 1; i < n; i++)
        {
            ThresholdResult key = results[i];
            int j = i - 1;
            while(j >= 0 && results[j].stats.expectancy < key.stats.expectancy)
            {
                results[j + 1] = results[j];
                j--;
            }
            results[j + 1] = key;
        }
    }

    CLogger     m_logger;
    int         m_count;
    int         m_lastCount;
    TelemetryRow m_rows[];
};

#endif

