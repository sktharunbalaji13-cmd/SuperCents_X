//+------------------------------------------------------------------+
//|                                           PromotionGate.mqh        |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  CI-pipeline style promotion gate.  A candidate configuration is
//  promoted only when every criterion PASSes against the locked
//  baseline, with the minimum sample sizes satisfied.
//
//  Minimum samples per configuration fingerprint:
//    - 10,000 shadow comparisons
//    -   500 qualified signals
//    -   300 settled trades
//  Below the minimums the gate reports INCONCLUSIVE â€” never promotes.
//+------------------------------------------------------------------+
#ifndef __PROMOTION_GATE_MQH__
#define __PROMOTION_GATE_MQH__

#include "../Telemetry/TelemetryTypes.mqh"
#include "CalibrationMetrics.mqh"
#include "../Core/Logger.mqh"

#define PROMO_MIN_SHADOW     10000
#define PROMO_MIN_SIGNALS      500
#define PROMO_MIN_TRADES       300

enum ENUM_CRITERION_VERDICT
{
    CRITERION_PASS = 0,
    CRITERION_FAIL,
    CRITERION_INCONCLUSIVE
};

struct PromotionCriterion
{
    string             name;
    string             description;
    double             candidate;
    double             baseline;
    double             pValue;
    ENUM_CRITERION_VERDICT verdict;

    PromotionCriterion(void)
        : name("")
        , description("")
        , candidate(0.0)
        , baseline(0.0)
        , pValue(1.0)
        , verdict(CRITERION_INCONCLUSIVE)
    {}
};

struct PromotionReport
{
    ulong             configFingerprint;
    string             configName;
    int                shadowComparisons;
    int                qualifiedSignals;
    int                settledTrades;
    int                decisionMatchCount;
    double             decisionMatchRate;
    int                directionMatchCount;
    double             directionMatchRate;
    PromotionCriterion criteria[8];
    int                criterionCount;
    bool               promoted;
    bool               inconclusive;

    PromotionReport(void)
        : configFingerprint(0)
        , configName("")
        , shadowComparisons(0)
        , qualifiedSignals(0)
        , settledTrades(0)
        , decisionMatchCount(0)
        , directionMatchCount(0)
        , decisionMatchRate(0.0)
        , directionMatchRate(0.0)
        , criterionCount(0)
        , promoted(false)
        , inconclusive(true)
    {}
};

class CPromotionGate
{
public:
    CPromotionGate(void)
        : m_logger(MODULE_UNKNOWN, "PromotionGate")
    {}

    //--- Evaluate a candidate config vs the locked baseline.
    //    rows[] must already be filtered to the candidate fingerprint.
    //    candidateThreshold / baselineThreshold are the confidence
    //    thresholds; candidateStats/baselineStats are precomputed stats
    //    (or pass stats from the optimizers directly).
    bool Evaluate(TelemetryRow &rows[], int count,
                  ulong fingerprint, const string configName,
                  double candidateThreshold, double baselineThreshold,
                  const TradeStats &candidateStats, const TradeStats &baselineStats,
                  PromotionReport &report)
    {
        report = PromotionReport();
        report.configFingerprint = fingerprint;
        report.configName = configName;

        //--- Sample-size gates first.
        report.shadowComparisons = count;
        report.qualifiedSignals = CountQualified(rows, count, candidateThreshold);
        report.settledTrades = candidateStats.trades;

        int matchCount = 0;
        int dirMatchCount = 0;
        int decidedRows = 0;
        for(int i = 0; i < count; i++)
        {
            if(rows[i].decisionMatch)
                matchCount++;
            if(rows[i].directionMatch)
                dirMatchCount++;
            decidedRows++;
        }
        report.decisionMatchCount = matchCount;
        report.directionMatchCount = dirMatchCount;
        report.decisionMatchRate = (decidedRows > 0) ? (double)matchCount / decidedRows : 0.0;
        report.directionMatchRate = (decidedRows > 0) ? (double)dirMatchCount / decidedRows : 0.0;

        bool enoughShadow = (count >= PROMO_MIN_SHADOW);
        bool enoughSignals = (report.qualifiedSignals >= PROMO_MIN_SIGNALS);
        bool enoughTrades = (report.settledTrades >= PROMO_MIN_TRADES);

        AddCriterion(report, "Sample: shadow comparisons",
                     StringFormat("need >= %d, have %d", PROMO_MIN_SHADOW, count),
                     count, PROMO_MIN_SHADOW, 0.0,
                     enoughShadow ? CRITERION_PASS : CRITERION_INCONCLUSIVE);
        AddCriterion(report, "Sample: qualified signals",
                     StringFormat("need >= %d, have %d", PROMO_MIN_SIGNALS, report.qualifiedSignals),
                     report.qualifiedSignals, PROMO_MIN_SIGNALS, 0.0,
                     enoughSignals ? CRITERION_PASS : CRITERION_INCONCLUSIVE);
        AddCriterion(report, "Sample: settled trades",
                     StringFormat("need >= %d, have %d", PROMO_MIN_TRADES, report.settledTrades),
                     report.settledTrades, PROMO_MIN_TRADES, 0.0,
                     enoughTrades ? CRITERION_PASS : CRITERION_INCONCLUSIVE);

        //--- Only run the statistical criteria when samples are adequate.
        if(!enoughShadow || !enoughSignals || !enoughTrades)
        {
            report.inconclusive = true;
            report.promoted = false;
            return false;
        }

        //--- Statistical criteria vs baseline.
        AddCriterion(report, "Expectancy improvement",
                     "candidate expectancy > baseline, p < 0.05",
                     candidateStats.expectancy, baselineStats.expectancy,
                     ExpectancyPValue(rows, count, candidateThreshold, baselineThreshold),
                     CRITERION_INCONCLUSIVE);
        AddCriterion(report, "Profit factor",
                     "candidate PF > baseline PF",
                     candidateStats.profitFactor, baselineStats.profitFactor,
                     0.0, CRITERION_INCONCLUSIVE);
        AddCriterion(report, "Win rate",
                     "candidate win rate >= baseline",
                     candidateStats.winRate, baselineStats.winRate,
                     0.0, CRITERION_INCONCLUSIVE);
        AddCriterion(report, "Max drawdown",
                     "candidate drawdown <= baseline (R units)",
                     candidateStats.maxDrawdown, baselineStats.maxDrawdown,
                     0.0, CRITERION_INCONCLUSIVE);
        AddCriterion(report, "Recovery factor",
                     "candidate recovery >= baseline",
                     candidateStats.recoveryFactor, baselineStats.recoveryFactor,
                     0.0, CRITERION_INCONCLUSIVE);

        //--- Finalize the statistical criteria.
        double p = report.criteria[3].pValue;
        report.criteria[3].verdict = (p < 0.05 && report.criteria[3].candidate > report.criteria[3].baseline)
            ? CRITERION_PASS : (report.criteria[3].candidate > report.criteria[3].baseline ? CRITERION_INCONCLUSIVE : CRITERION_FAIL);
        report.criteria[4].verdict = (report.criteria[4].candidate > report.criteria[4].baseline)
            ? CRITERION_PASS : CRITERION_FAIL;
        report.criteria[5].verdict = (report.criteria[5].candidate >= report.criteria[5].baseline)
            ? CRITERION_PASS : CRITERION_FAIL;
        report.criteria[6].verdict = (report.criteria[6].candidate <= report.criteria[6].baseline)
            ? CRITERION_PASS : CRITERION_FAIL;
        report.criteria[7].verdict = (report.criteria[7].candidate >= report.criteria[7].baseline)
            ? CRITERION_PASS : CRITERION_FAIL;

        //--- Overall: every criterion must PASS.
        bool allPass = true;
        bool anyInconclusive = false;
        for(int i = 0; i < report.criterionCount; i++)
        {
            if(report.criteria[i].verdict == CRITERION_FAIL)
                allPass = false;
            if(report.criteria[i].verdict == CRITERION_INCONCLUSIVE)
                anyInconclusive = true;
        }

        report.inconclusive = anyInconclusive;
        report.promoted = allPass && !anyInconclusive;
        return report.promoted;
    }

    //--- Render the report as a CI-style block for the log.
    string RenderReport(const PromotionReport &report)
    {
        string out = "";
        out += "========================== Promotion Gate ==========================\n";
        out += "Config : " + report.configName + "\n";
        out += "Fingerprint : " + ConfigFingerprintToHex(report.configFingerprint) + "\n";
        out += StringFormat("Samples : %d shadow, %d signals, %d trades\n",
                            report.shadowComparisons, report.qualifiedSignals, report.settledTrades);
        out += StringFormat("Agreement : decisionMatch %.1f%% (%d), directionMatch %.1f%% (%d)\n",
                            report.decisionMatchRate * 100.0, report.decisionMatchCount,
                            report.directionMatchRate * 100.0, report.directionMatchCount);
        out += "-------------------------------------------------------------------\n";
        out += StringFormat("%-10s | %-42s | %-10s | %-10s\n", "Criterion", "Description", "Candidate", "Baseline");
        for(int i = 0; i < report.criterionCount; i++)
        {
            string verdictStr = (report.criteria[i].verdict == CRITERION_PASS) ? "PASS"
                : (report.criteria[i].verdict == CRITERION_FAIL) ? "FAIL" : "INCONCLUSIVE";
            out += StringFormat("%-10s | %-42s | %-10.4f | %-10.4f\n",
                                verdictStr, report.criteria[i].name,
                                report.criteria[i].candidate, report.criteria[i].baseline);
        }
        out += "-------------------------------------------------------------------\n";
        out += report.promoted ? "Overall : PROMOTED\n"
            : report.inconclusive ? "Overall : INCONCLUSIVE (samples or significance insufficient)\n"
            : "Overall : NOT PROMOTED (criteria failed)\n";
        out += "===================================================================";
        return out;
    }

private:
    void AddCriterion(PromotionReport &report, const string name, const string desc,
                      double candidate, double baseline, double pValue,
                      ENUM_CRITERION_VERDICT verdict)
    {
        int i = report.criterionCount;
        if(i >= 8)
            return;
        report.criteria[i].name = name;
        report.criteria[i].description = desc;
        report.criteria[i].candidate = candidate;
        report.criteria[i].baseline = baseline;
        report.criteria[i].pValue = pValue;
        report.criteria[i].verdict = verdict;
        report.criterionCount++;
    }

    int CountQualified(TelemetryRow &rows[], int count, double threshold)
    {
        int n = 0;
        for(int i = 0; i < count; i++)
        {
            if(rows[i].ReplayDecision(threshold))
                n++;
        }
        return n;
    }

    //--- Welch p-value: candidate group vs baseline group (both replayed).
    double ExpectancyPValue(TelemetryRow &rows[], int count,
                            double candidateThreshold, double baselineThreshold)
    {
        double a[];
        double b[];
        ArrayResize(a, count);
        ArrayResize(b, count);

        int na = 0;
        int nb = 0;
        for(int i = 0; i < count; i++)
        {
            if(rows[i].outcome == (int)TELEMETRY_OUTCOME_UNKNOWN)
                continue;
            if(rows[i].ReplayDecision(candidateThreshold))
                a[na++] = rows[i].rMultiple;
            if(rows[i].ReplayDecision(baselineThreshold))
                b[nb++] = rows[i].rMultiple;
        }
        return CalibrationWelchPValue(a, na, b, nb);
    }

    string ConfigFingerprintToHex(ulong fp)
    {
        return StringFormat("%016llX", fp);
    }

    CLogger m_logger;
};

#endif


