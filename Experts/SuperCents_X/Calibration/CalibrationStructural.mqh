//+------------------------------------------------------------------+
//|                                        CalibrationStructural.mqh   |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 16.1B (v3.0)   |
//+------------------------------------------------------------------+
//  Structural diagnostics for the confidence score (Sprint 16.1B).
//  Answers the question raised by 16.2: why is the raw score ordering
//  weak / anti-correlated with outcomes?
//
//  Sections:
//    A. Component activation + marginal predictive power (absent vs
//       present: trades, WR, PF, expectancy, meanConf, meanR).
//    B. Fired-count decomposition (rows grouped by number of active
//       components; does confidence grow with count, and does win rate?).
//    C. Rank correlation (Spearman rho, Kendall tau-b) between
//       confidence and rMultiple / win-loss, plus per-component
//       Spearman between raw score and rMultiple.
//    D. Information contribution: ablation replay at the gate threshold
//       (component weight zeroed vs component alone vs full score).
//+------------------------------------------------------------------+
#ifndef __CALIBRATION_STRUCTURAL_MQH__
#define __CALIBRATION_STRUCTURAL_MQH__

#include "../Telemetry/TelemetryTypes.mqh"
#include "CalibrationMetrics.mqh"

#define CALIB_STRUCT_MAX_FIRED   (TELEMETRY_COMPONENT_COUNT + 1)   // 0..6

//--- Section A: one entry per component.
struct StructuralComponentStat
{
    string name;
    int    component;            // index into the weights array (0..5)
    int    totalRows;
    int    activeRows;           // raw score > 0
    double activationPct;
    //--- absent group (component not active)
    int    absentTrades;
    double absentWinRate, absentProfitFactor, absentExpectancy;
    double absentMeanConf, absentMeanR;
    //--- present group
    int    presentTrades;
    double presentWinRate, presentProfitFactor, presentExpectancy;
    double presentMeanConf, presentMeanR;
};

//--- Section B: one entry per fired count.
struct StructuralFiredCount
{
    int    fired;                // 0..6
    int    trades;
    double winRate, profitFactor, expectancy;
    double meanConf, meanR;
};

//--- Section C: one entry per correlation.
struct StructuralCorrelation
{
    string label;
    double value;
    int    n;
};

//--- Section D: one entry per component.
struct StructuralAblation
{
    string name;
    int    component;
    double baselineExp, baselinePF, baselineWR, baselineTrades;
    double looExp, looPF, looWR, looTrades;
    double aloneExp, alonePF, aloneWR, aloneTrades;
    double deltaExp, deltaPF, deltaTrades;
    double infoContrib;          // |deltaExp| / (|baselineExp| + 0.01)
};

//+------------------------------------------------------------------+
//| Rank correlation machinery (average ranks, deterministic).        |
//+------------------------------------------------------------------+
void CalibrationRanks(const double &values[], int n, double &ranks[])
{
    ArrayResize(ranks, n);
    if(n < 1)
        return;
    double v[];
    int idx[];
    ArrayResize(v, n);
    ArrayResize(idx, n);
    for(int i = 0; i < n; i++)
    {
        v[i] = values[i];
        idx[i] = i;
    }
    //--- Bottom-up merge sort on (v, idx) pairs.
    double tmpV[];
    int tmpI[];
    ArrayResize(tmpV, n);
    ArrayResize(tmpI, n);
    for(int width = 1; width < n; width *= 2)
    {
        for(int lo = 0; lo < n; lo += 2 * width)
        {
            int mid = (lo + width < n) ? lo + width : n;
            int hi = (lo + 2 * width < n) ? lo + 2 * width : n;
            int a = lo, b = mid, o = lo;
            while(a < mid && b < hi)
            {
                if(v[a] < v[b])
                {
                    tmpV[o] = v[a];  tmpI[o] = idx[a];  a++;
                }
                else
                {
                    tmpV[o] = v[b];  tmpI[o] = idx[b];  b++;
                }
                o++;
            }
            while(a < mid)
            {
                tmpV[o] = v[a];  tmpI[o] = idx[a];  a++;  o++;
            }
            while(b < hi)
            {
                tmpV[o] = v[b];  tmpI[o] = idx[b];  b++;  o++;
            }
        }
        for(int i = 0; i < n; i++)
        {
            v[i] = tmpV[i];
            idx[i] = tmpI[i];
        }
    }
    //--- Average ranks within tie groups (1-based convention).
    int i = 0;
    while(i < n)
    {
        int j = i;
        while(j < n && v[j] == v[i])
            j++;
        double avg = (double)(i + j + 1) / 2.0;
        for(int k = i; k < j; k++)
            ranks[idx[k]] = avg;
        i = j;
    }
}

//--- Spearman rho (average ranks; 0 if n < 3).
double CalibrationSpearman(const double &a[], const double &b[], int n)
{
    if(n < 3)
        return 0.0;
    double ra[], rb[];
    CalibrationRanks(a, n, ra);
    CalibrationRanks(b, n, rb);
    double sumD2 = 0.0;
    for(int i = 0; i < n; i++)
    {
        double d = ra[i] - rb[i];
        sumD2 += d * d;
    }
    double denom = (double)n * ((double)n * (double)n - 1.0) / 6.0;
    if(denom == 0.0)
        return 0.0;
    return 1.0 - sumD2 / denom;
}

//--- Kendall tau-b (ties handled; 0 if n < 3).
double CalibrationKendallTau(const double &a[], const double &b[], int n)
{
    if(n < 3)
        return 0.0;
    long concordant = 0;
    long discordant = 0;
    long tiesA = 0;
    long tiesB = 0;
    for(int i = 0; i < n - 1; i++)
    {
        for(int j = i + 1; j < n; j++)
        {
            int signA = (a[i] > a[j]) ? 1 : (a[i] < a[j]) ? -1 : 0;
            int signB = (b[i] > b[j]) ? 1 : (b[i] < b[j]) ? -1 : 0;
            if(signA == 0 && signB == 0)
                continue;
            if(signA * signB > 0)
                concordant++;
            else if(signA * signB < 0)
                discordant++;
            else
            {
                if(signA == 0)
                    tiesB++;
                else
                    tiesA++;
            }
        }
    }
    double p = (double)concordant;
    double q = (double)discordant;
    double t = (double)tiesA;
    double u = (double)tiesB;
    double denom = MathSqrt((p + q + t) * (p + q + u));
    if(denom == 0.0)
        return 0.0;
    return (p - q) / denom;
}

//+------------------------------------------------------------------+
//| Component helpers.                                                |
//+------------------------------------------------------------------+
string CalibrationStructuralComponentName(int index)
{
    switch(index)
    {
        case 0: return "structure";
        case 1: return "orderBlock";
        case 2: return "fvg";
        case 3: return "liquidity";
        case 4: return "trend";
        case 5: return "premiumDiscount";
    }
    return "unknown";
}

//--- NOTE: the canonical component index in this module is the WEIGHT
//    array order used by TelemetryRow::ReplayConfidence:
//        0 structure, 1 orderBlock, 2 fvg, 3 liquidity, 4 trend, 5 premiumDiscount
//    That is NOT the ENUM_CONFLUENCE_COMPONENT order (structure, trend,
//    orderBlock, fvg, liquidity, premiumDiscount).
ENUM_CONFLUENCE_COMPONENT CalibrationStructuralToEnum(int weightIndex)
{
    switch(weightIndex)
    {
        case 0: return COMPONENT_STRUCTURE;
        case 1: return COMPONENT_ORDER_BLOCK;
        case 2: return COMPONENT_FVG;
        case 3: return COMPONENT_LIQUIDITY;
        case 4: return COMPONENT_TREND;
        case 5: return COMPONENT_PREMIUM_DISCOUNT;
    }
    return COMPONENT_STRUCTURE;
}

double CalibrationStructuralGetWeight(const TelemetryRow &row, int index)
{
    switch(index)
    {
        case 0: return row.structureWeight;
        case 1: return row.obWeight;
        case 2: return row.fvgWeight;
        case 3: return row.liquidityWeight;
        case 4: return row.trendWeight;
        case 5: return row.pdWeight;
    }
    return 0.0;
}

bool CalibrationStructuralActive(const TelemetryRow &row, int index)
{
    return row.GetRaw(CalibrationStructuralToEnum(index)) > 1e-9;
}

int CalibrationStructuralActiveCount(const TelemetryRow &row)
{
    int n = 0;
    for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
    {
        if(CalibrationStructuralActive(row, i))
            n++;
    }
    return n;
}

//--- Replay the weighted score with a modified weight set.
//    zeroIndex >= 0 -> that component's weight zeroed (leave-one-out);
//    onlyIndex  >= 0 -> all weights except that component zeroed (alone).
//    Returns the 0..1 confidence, or -1 if all weights are zero.
double CalibrationStructuralReplay(const TelemetryRow &row, int zeroIndex, int onlyIndex)
{
    double w[TELEMETRY_COMPONENT_COUNT];
    double totalWeight = 0.0;
    for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
    {
        w[i] = CalibrationStructuralGetWeight(row, i);
        totalWeight += w[i];
    }
    if(onlyIndex >= 0)
    {
        for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
        {
            if(i != onlyIndex)
                w[i] = 0.0;
        }
    }
    else if(zeroIndex >= 0)
    {
        w[zeroIndex] = 0.0;
    }
    if(totalWeight <= 0.0)
        return -1.0;
    return row.ReplayConfidence(w) / 100.0;
}

//+------------------------------------------------------------------+
//| Subset stats over an eligible mask (decided rows only).          |
//+------------------------------------------------------------------+
void CalibrationStructuralSubsetStats(TelemetryRow &rows[], const bool &eligible[], int count,
                                      int &trades, double &winRate,
                                      double &profitFactor, double &expectancy,
                                      double &meanConf, double &meanR)
{
    trades = 0;
    winRate = 0.0;
    profitFactor = 0.0;
    expectancy = 0.0;
    meanConf = 0.0;
    meanR = 0.0;

    TradeStats stats;
    CalibrationComputeStats(rows, eligible, count, stats);
    trades = stats.trades;
    winRate = stats.winRate;
    profitFactor = stats.profitFactor;
    expectancy = stats.expectancy;

    double confSum = 0.0;
    double rSum = 0.0;
    int decided = 0;
    for(int i = 0; i < count; i++)
    {
        if(!eligible[i] || rows[i].outcome == (int)TELEMETRY_OUTCOME_UNKNOWN)
            continue;
        confSum += rows[i].confidence;
        rSum += rows[i].rMultiple;
        decided++;
    }
    if(decided > 0)
    {
        meanConf = confSum / (double)decided;
        meanR = rSum / (double)decided;
    }
}

//+------------------------------------------------------------------+
//| Section A: activation + marginal predictive power per component.  |
//+------------------------------------------------------------------+
void CalibrationStructuralComponents(TelemetryRow &rows[], int count,
                                     StructuralComponentStat &stats[])
{
    ArrayResize(stats, TELEMETRY_COMPONENT_COUNT);
    bool absent[], present[];
    ArrayResize(absent, count);
    ArrayResize(present, count);

    for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
    {
        stats[c].name = CalibrationStructuralComponentName(c);
        stats[c].component = c;
        stats[c].totalRows = count;
        stats[c].activeRows = 0;

        for(int i = 0; i < count; i++)
        {
            bool active = CalibrationStructuralActive(rows[i], c);
            absent[i] = !active;
            present[i] = active;
            if(active)
                stats[c].activeRows++;
        }
        stats[c].activationPct = (count > 0) ? 100.0 * (double)stats[c].activeRows / (double)count : 0.0;

        CalibrationStructuralSubsetStats(rows, absent, count,
                                         stats[c].absentTrades, stats[c].absentWinRate,
                                         stats[c].absentProfitFactor, stats[c].absentExpectancy,
                                         stats[c].absentMeanConf, stats[c].absentMeanR);
        CalibrationStructuralSubsetStats(rows, present, count,
                                         stats[c].presentTrades, stats[c].presentWinRate,
                                         stats[c].presentProfitFactor, stats[c].presentExpectancy,
                                         stats[c].presentMeanConf, stats[c].presentMeanR);
    }
}

//+------------------------------------------------------------------+
//| Section B: fired-count decomposition.                             |
//+------------------------------------------------------------------+
void CalibrationStructuralFiredCounts(TelemetryRow &rows[], int count,
                                      StructuralFiredCount &counts[])
{
    ArrayResize(counts, CALIB_STRUCT_MAX_FIRED);
    bool masks[][CALIB_STRUCT_MAX_FIRED];
    ArrayResize(masks, count);
    for(int i = 0; i < count; i++)
    {
        for(int g = 0; g < CALIB_STRUCT_MAX_FIRED; g++)
            masks[i][g] = false;
        int fired = CalibrationStructuralActiveCount(rows[i]);
        if(fired >= 0 && fired < CALIB_STRUCT_MAX_FIRED)
            masks[i][fired] = true;
    }

    for(int g = 0; g < CALIB_STRUCT_MAX_FIRED; g++)
    {
        bool eligible[];
        ArrayResize(eligible, count);
        for(int i = 0; i < count; i++)
            eligible[i] = masks[i][g];

        counts[g].fired = g;
        int trades = 0;
        double wr = 0.0, pf = 0.0, expv = 0.0, meanConf = 0.0, meanR = 0.0;
        CalibrationStructuralSubsetStats(rows, eligible, count,
                                         trades, wr, pf, expv, meanConf, meanR);
        counts[g].trades = trades;
        counts[g].winRate = wr;
        counts[g].profitFactor = pf;
        counts[g].expectancy = expv;
        counts[g].meanConf = meanConf;
        counts[g].meanR = meanR;
    }
}

//+------------------------------------------------------------------+
//| Section C: rank correlations on decided rows.                    |
//+------------------------------------------------------------------+
void CalibrationStructuralCorrelations(TelemetryRow &rows[], int count,
                                       StructuralCorrelation &corr[])
{
    //--- decided-by-outcome rows for rMultiple; win/loss rows for wl.
    int nR = 0, nWl = 0;
    for(int i = 0; i < count; i++)
    {
        if(rows[i].outcome != (int)TELEMETRY_OUTCOME_UNKNOWN)
            nR++;
        if(rows[i].outcome == (int)TELEMETRY_OUTCOME_WIN ||
           rows[i].outcome == (int)TELEMETRY_OUTCOME_LOSS)
            nWl++;
    }

    double confR[], r[];
    double confWl[], wl[];
    ArrayResize(confR, nR); ArrayResize(r, nR);
    ArrayResize(confWl, nWl); ArrayResize(wl, nWl);
    int iR = 0, iWl = 0;
    for(int i = 0; i < count; i++)
    {
        if(rows[i].outcome != (int)TELEMETRY_OUTCOME_UNKNOWN)
        {
            confR[iR] = rows[i].confidence;
            r[iR] = rows[i].rMultiple;
            iR++;
        }
        if(rows[i].outcome == (int)TELEMETRY_OUTCOME_WIN ||
           rows[i].outcome == (int)TELEMETRY_OUTCOME_LOSS)
        {
            confWl[iWl] = rows[i].confidence;
            wl[iWl] = (rows[i].outcome == (int)TELEMETRY_OUTCOME_WIN) ? 1.0 : 0.0;
            iWl++;
        }
    }

    int n = 0;
    ArrayResize(corr, 4 + TELEMETRY_COMPONENT_COUNT);
    corr[n].label = "spearman_conf_r";
    corr[n].value = CalibrationSpearman(confR, r, nR);
    corr[n].n = nR;
    n++;
    corr[n].label = "kendall_conf_r";
    corr[n].value = CalibrationKendallTau(confR, r, nR);
    corr[n].n = nR;
    n++;
    corr[n].label = "spearman_conf_wl";
    corr[n].value = CalibrationSpearman(confWl, wl, nWl);
    corr[n].n = nWl;
    n++;
    corr[n].label = "kendall_conf_wl";
    corr[n].value = CalibrationKendallTau(confWl, wl, nWl);
    corr[n].n = nWl;
    n++;

    //--- Per-component raw score vs rMultiple (Spearman).
    for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
    {
        double rawR[];
        ArrayResize(rawR, nR);
        iR = 0;
        for(int i = 0; i < count; i++)
        {
            if(rows[i].outcome == (int)TELEMETRY_OUTCOME_UNKNOWN)
                continue;
            rawR[iR] = rows[i].GetRaw(CalibrationStructuralToEnum(c));
            iR++;
        }
        corr[n].label = "spearman_" + CalibrationStructuralComponentName(c) + "_r";
        corr[n].value = CalibrationSpearman(rawR, r, nR);
        corr[n].n = nR;
        n++;
    }
}

//+------------------------------------------------------------------+
//| Section D: information contribution (ablation replay at gate).   |
//+------------------------------------------------------------------+
void CalibrationStructuralAblation(TelemetryRow &rows[], int count, double threshold,
                                   StructuralAblation &abl[])
{
    ArrayResize(abl, TELEMETRY_COMPONENT_COUNT);

    bool baseEligible[];
    ArrayResize(baseEligible, count);
    for(int i = 0; i < count; i++)
        baseEligible[i] = rows[i].ReplayDecision(threshold);
    TradeStats baseStats;
    CalibrationComputeStats(rows, baseEligible, count, baseStats);

    bool eligible[];
    ArrayResize(eligible, count);

    for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
    {
        abl[c].name = CalibrationStructuralComponentName(c);
        abl[c].component = c;
        abl[c].baselineExp = baseStats.expectancy;
        abl[c].baselinePF = baseStats.profitFactor;
        abl[c].baselineWR = baseStats.winRate;
        abl[c].baselineTrades = baseStats.trades;

        for(int i = 0; i < count; i++)
        {
            double conf = CalibrationStructuralReplay(rows[i], c, -1);
            TelemetryRow copy = rows[i];
            copy.confidence = conf;
            eligible[i] = (conf >= 0.0) ? copy.ReplayDecision(threshold) : false;
        }
        TradeStats looStats;
        CalibrationComputeStats(rows, eligible, count, looStats);
        abl[c].looExp = looStats.expectancy;
        abl[c].looPF = looStats.profitFactor;
        abl[c].looWR = looStats.winRate;
        abl[c].looTrades = looStats.trades;

        for(int i = 0; i < count; i++)
        {
            double conf = CalibrationStructuralReplay(rows[i], -1, c);
            TelemetryRow copy = rows[i];
            copy.confidence = conf;
            eligible[i] = (conf >= 0.0) ? copy.ReplayDecision(threshold) : false;
        }
        TradeStats aloneStats;
        CalibrationComputeStats(rows, eligible, count, aloneStats);
        abl[c].aloneExp = aloneStats.expectancy;
        abl[c].alonePF = aloneStats.profitFactor;
        abl[c].aloneWR = aloneStats.winRate;
        abl[c].aloneTrades = aloneStats.trades;

        abl[c].deltaExp = abl[c].looExp - abl[c].baselineExp;
        abl[c].deltaPF = abl[c].looPF - abl[c].baselinePF;
        abl[c].deltaTrades = (double)(abl[c].looTrades - abl[c].baselineTrades);
        abl[c].infoContrib = MathAbs(abl[c].deltaExp) / (MathAbs(abl[c].baselineExp) + 0.01);
    }
}

#endif
