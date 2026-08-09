//+------------------------------------------------------------------+
//|                                         WeightOptimizer.mqh        |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  3-stage weight search over the 6 confluence weights (S, OB, FVG,
//  Liq, Trend, PD) using offline ReplayConfidence:
//
//    Stage 1: coarse scan, step 10 (0..100, sum 100)     ~3,003 evals
//    Stage 2: fine scan,  step 5  around top-5 weights   ~1-2k evals
//    Stage 3: hill climb, step +/-2 on top-3 weights     <200 evals
//
//  Score = expectancy of qualified trades; tie-break by profit factor.
//  Threshold is on the 0..100 ReplayConfidence scale (not 0..1).
//+------------------------------------------------------------------+
#ifndef __WEIGHT_OPTIMIZER_MQH__
#define __WEIGHT_OPTIMIZER_MQH__

#include "../Telemetry/TelemetryTypes.mqh"
#include "CalibrationMetrics.mqh"
#include "../Core/Logger.mqh"

#define WEIGHT_OPT_MAX_ROWS   5000
#define WEIGHT_OPT_COARSE_STEP  10
#define WEIGHT_OPT_FINE_STEP     5
#define WEIGHT_OPT_CLIMB_STEP    2
#define WEIGHT_OPT_STAGE1_TOP    5
#define WEIGHT_OPT_STAGE2_TOP    3

struct WeightCandidate
{
    double weights[TELEMETRY_COMPONENT_COUNT];
    double expectancy;
    double profitFactor;
    double winRate;
    double maxDrawdown;
    double pValueVsBaseline;

    WeightCandidate(void)
        : expectancy(0.0)
        , profitFactor(0.0)
        , winRate(0.0)
        , maxDrawdown(0.0)
        , pValueVsBaseline(1.0)
    {
        for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
            weights[i] = 0.0;
    }
};

class CWeightOptimizer
{
public:
    CWeightOptimizer(void)
        : m_logger(MODULE_UNKNOWN, "WeightOptimizer")
        , m_count(0)
        , m_evals(0)
        , m_rankedCount(0)
    {}

    void Load(TelemetryRow &rows[], int count)
    {
        m_count = (count > WEIGHT_OPT_MAX_ROWS) ? WEIGHT_OPT_MAX_ROWS : count;
        ArrayResize(m_rows, m_count);
        for(int i = 0; i < m_count; i++)
            m_rows[i] = rows[i];
    }

    //--- Run all three stages.  baseline[6] = production weights (unused
    //    for scoring; kept for call-site symmetry with the gate).
    //    best is filled with the winner; returns total evaluations.
    int Optimize(const double &baseline[], double threshold, WeightCandidate &best)
    {
        m_evals = 0;

        //--- Stage 1: coarse scan, step 10, keep top 5.
        WeightCandidate coarse;
        m_rankedCount = 0;
        EnumerateWeights(WEIGHT_OPT_COARSE_STEP, WEIGHT_OPT_STAGE1_TOP, threshold, coarse);
        CopyRankedTo(m_stage1Top);

        //--- Stage 2: fine scan, step 5, around the top-5 weights, keep top 3.
        WeightCandidate fine;
        m_rankedCount = 0;
        ScanNeighborhood(WEIGHT_OPT_FINE_STEP, WEIGHT_OPT_STAGE2_TOP, threshold, fine);

        //--- Stage 3: hill climb, step +/-2 on the top-3 weights.
        WeightCandidate climbed = fine;
        bool improved = true;
        while(improved && m_evals < 100000)
        {
            improved = false;
            for(int a = 0; a < WEIGHT_OPT_STAGE2_TOP; a++)
            {
                for(int delta = -WEIGHT_OPT_CLIMB_STEP; delta <= WEIGHT_OPT_CLIMB_STEP;
                    delta += WEIGHT_OPT_CLIMB_STEP)
                {
                    if(delta == 0)
                        continue;
                    WeightCandidate trial = climbed;
                    if(!ShiftWeight(trial.weights, a, delta))
                        continue;
                    Score(trial, threshold);
                    if(Better(trial, climbed))
                    {
                        climbed = trial;
                        improved = true;
                    }
                }
            }
        }

        best = climbed;
        return m_evals;
    }

    int GetEvals(void) const { return m_evals; }

private:
    //--- Enumerate all 6-weight compositions with sum 100 and step s.
    //    Keeps the top `top` candidates (by score) in m_ranked.
    void EnumerateWeights(int step, int top, double threshold, WeightCandidate &best)
    {
        double w[TELEMETRY_COMPONENT_COUNT];
        best = WeightCandidate();

        for(int s = 0; s <= 100; s += step)
        {
            w[0] = s;
            for(int ob = 0; ob + s <= 100; ob += step)
            {
                w[1] = ob;
                for(int fvg = 0; fvg + s + ob <= 100; fvg += step)
                {
                    w[2] = fvg;
                    for(int liq = 0; liq + s + ob + fvg <= 100; liq += step)
                    {
                        w[3] = liq;
                        for(int tr = 0; tr + s + ob + fvg + liq <= 100; tr += step)
                        {
                            w[4] = tr;
                            w[5] = 100 - s - ob - fvg - liq - tr;

                            WeightCandidate cand;
                            for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
                                cand.weights[i] = w[i];
                            Score(cand, threshold);

                            InsertRanked(cand, top);
                            if(Better(cand, best))
                                best = cand;
                        }
                    }
                }
            }
        }
    }

    //--- Scan a neighborhood (each dimension +/- 2*step) of m_stage1Top
    //    at step s, keeping the top `top` candidates in m_ranked.
    void ScanNeighborhood(int step, int top, double threshold, WeightCandidate &best)
    {
        best = WeightCandidate();

        for(int c = 0; c < WEIGHT_OPT_STAGE1_TOP; c++)
        {
            double w[TELEMETRY_COMPONENT_COUNT];
            for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
                w[i] = m_stage1Top[c].weights[i];

            for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
            {
                for(int delta = -2 * step; delta <= 2 * step; delta += step)
                {
                    if(delta == 0)
                        continue;
                    double trial[TELEMETRY_COMPONENT_COUNT];
                    for(int j = 0; j < TELEMETRY_COMPONENT_COUNT; j++)
                        trial[j] = w[j];
                    if(!ShiftWeight(trial, i, delta))
                        continue;
                    if(!IsValidWeights(trial))
                        continue;

                    WeightCandidate cand;
                    for(int j = 0; j < TELEMETRY_COMPONENT_COUNT; j++)
                        cand.weights[j] = trial[j];
                    Score(cand, threshold);

                    InsertRanked(cand, top);
                    if(Better(cand, best))
                        best = cand;
                }
            }
        }
    }

    void CopyRankedTo(WeightCandidate &dst[])
    {
        for(int i = 0; i < m_rankedCount; i++)
            dst[i] = m_ranked[i];
    }

    //--- Shift one weight by delta and rebalance the last weight to keep sum 100.
    bool ShiftWeight(double &w[], int index, double delta)
    {
        int other = (index == TELEMETRY_COMPONENT_COUNT - 1) ? 4 : TELEMETRY_COMPONENT_COUNT - 1;
        if(w[index] + delta < 0.0 || w[index] + delta > 100.0)
            return false;
        if(w[other] - delta < 0.0 || w[other] - delta > 100.0)
            return false;
        w[index] += delta;
        w[other] -= delta;
        return true;
    }

    bool IsValidWeights(const double &w[])
    {
        double sum = 0.0;
        for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
        {
            if(w[i] < 0.0 || w[i] > 100.0)
                return false;
            sum += w[i];
        }
        return MathAbs(sum - 100.0) < 0.01;
    }

    //--- Score a weight set: replay confidence, apply threshold + stored
    //    validator results, compute expectancy over settled outcomes.
    void Score(WeightCandidate &cand, double threshold)
    {
        bool eligible[];
        ArrayResize(eligible, m_count);
        int qualified = 0;

        for(int i = 0; i < m_count; i++)
        {
            bool pass = m_rows[i].ReplayConfidence(cand.weights) >= threshold;
            if(pass)
            {
                for(int v = 0; v < m_rows[i].validatorCount; v++)
                {
                    if(m_rows[i].validators[v].name == "ConfluenceValidator")
                        continue;
                    if(m_rows[i].validators[v].result == FILTER_FAIL)
                    {
                        pass = false;
                        break;
                    }
                }
            }
            eligible[i] = pass;
            if(pass)
                qualified++;
        }

        TradeStats stats;
        CalibrationComputeStats(m_rows, eligible, m_count, stats);
        cand.expectancy = stats.expectancy;
        cand.profitFactor = stats.profitFactor;
        cand.winRate = stats.winRate;
        cand.maxDrawdown = stats.maxDrawdown;
        m_evals++;
    }

    //--- Better = higher expectancy; tie-break by profit factor.
    bool Better(const WeightCandidate &a, const WeightCandidate &b)
    {
        if(a.expectancy > b.expectancy + 1e-9)
            return true;
        if(MathAbs(a.expectancy - b.expectancy) <= 1e-9)
            return a.profitFactor > b.profitFactor;
        return false;
    }

    //--- Insert candidate into m_ranked (expectancy desc), capped at `top`.
    //    m_ranked holds fully-scored candidates so ranking compares real stats.
    void InsertRanked(const WeightCandidate &cand, int top)
    {
        //--- Skip duplicates.
        for(int i = 0; i < m_rankedCount; i++)
        {
            bool same = true;
            for(int j = 0; j < TELEMETRY_COMPONENT_COUNT; j++)
            {
                if(m_ranked[i].weights[j] != cand.weights[j])
                {
                    same = false;
                    break;
                }
            }
            if(same)
                return;
        }

        //--- Find the insertion slot (first rank we beat).
        int slot = -1;
        int limit = (m_rankedCount < top) ? m_rankedCount : top;
        for(int i = 0; i < limit; i++)
        {
            if(Better(cand, m_ranked[i]))
            {
                slot = i;
                break;
            }
        }

        if(slot < 0)
        {
            if(m_rankedCount < top)
                m_ranked[m_rankedCount++] = cand;
            return;
        }

        //--- Shift down and insert.
        int last = (m_rankedCount < top) ? m_rankedCount : top - 1;
        for(int k = last; k > slot; k--)
            m_ranked[k] = m_ranked[k - 1];
        m_ranked[slot] = cand;
        if(m_rankedCount < top)
            m_rankedCount++;
    }

    CLogger m_logger;
    int     m_count;
    int     m_evals;
    int     m_rankedCount;
    WeightCandidate m_ranked[WEIGHT_OPT_STAGE1_TOP];
    WeightCandidate m_stage1Top[WEIGHT_OPT_STAGE1_TOP];
    TelemetryRow m_rows[];
};

#endif

