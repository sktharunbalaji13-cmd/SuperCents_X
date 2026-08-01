//+------------------------------------------------------------------+
//|                                        ExperimentRunner.mqh        |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Orchestrates offline calibration experiments on stored telemetry:
//
//    CALIB_MODE_THRESHOLD        - sweep confidence thresholds
//    CALIB_MODE_WEIGHTS          - 3-stage weight search
//    CALIB_MODE_ABLATION         - validator leave-one-out (baseline)
//    CALIB_MODE_PROMOTION        - candidate vs baseline gate
//    CALIB_MODE_ABLATION_CROSSCHECK - ablation at the candidate threshold
//    CALIB_MODE_CALIBRATION      - confidence measurement baseline (16.1)
//
//  Every run writes a timestamped CSV report + experiment manifest
//  under Files/Calibration/ (FILE_COMMON, same as the telemetry store).
//+------------------------------------------------------------------+
#ifndef __EXPERIMENT_RUNNER_MQH__
#define __EXPERIMENT_RUNNER_MQH__

#include "../Core/Logger.mqh"
#include "../Telemetry/TelemetryTypes.mqh"
#include "../Telemetry/CalibrationDataset.mqh"
#include "../Optimization/ExperimentManifest.mqh"
#include "CalibrationMetrics.mqh"
#include "CalibrationReport.mqh"
#include "ThresholdOptimizer.mqh"
#include "WeightOptimizer.mqh"
#include "ValidatorAttribution.mqh"
#include "PromotionGate.mqh"

#define CALIB_MAX_DATASET_ROWS   100000

enum ENUM_CALIBRATION_MODE
{
    CALIB_MODE_THRESHOLD = 0,
    CALIB_MODE_WEIGHTS,
    CALIB_MODE_ABLATION,
    CALIB_MODE_PROMOTION,
    CALIB_MODE_ABLATION_CROSSCHECK,
    CALIB_MODE_CALIBRATION
};

class CExperimentRunner
{
public:
    CExperimentRunner(void)
        : m_logger(MODULE_UNKNOWN, "ExperimentRunner")
        , m_datasetDir("Telemetry")
        , m_outputDir("Calibration")
    {}

    void SetDirectories(const string datasetDir, const string outputDir)
    {
        m_datasetDir = datasetDir;
        m_outputDir = outputDir;
    }

    //--- Load the full telemetry store.  Returns row count.
    int LoadDataset(void)
    {
        m_dataset.Clear();
        int files = m_dataset.LoadDir(m_datasetDir);
        int rows = m_dataset.GetCount();
        m_logger.LogInfo(StringFormat("Calibration: loaded %d rows from %d files (skipped %d)",
                                      rows, files, m_dataset.GetSkippedRows()));
        return rows;
    }

    int GetDatasetCount(void) const { return m_dataset.GetCount(); }
    bool GetRow(int index, TelemetryRow &out) { return m_dataset.GetRow(index, out); }

    //--- Copy one fingerprint's rows into the caller's buffer (dynamic array).
    int GetFingerprintRows(ulong fp, TelemetryRow &rows[])
    {
        CCalibrationDataset filtered;
        if(!m_dataset.FilterByFingerprint(fp, filtered))
            return 0;
        int n = filtered.GetCount();
        ArrayResize(rows, n);
        for(int i = 0; i < n; i++)
        {
            if(!filtered.GetRow(i, rows[i]))
                break;
        }
        return n;
    }

    //--- Run one experiment.  cfg supplies baseline threshold/weights.
    bool Run(ENUM_CALIBRATION_MODE mode, const CalibrationConfig &cfg, ulong fp)
    {
        string modeName = ModeName(mode);
        string hex = FpToHex(fp);

        TelemetryRow rows[];
        int count = GetFingerprintRows(fp, rows);
        if(count == 0)
        {
            m_logger.LogWarn(StringFormat("Calibration: no rows for fingerprint %s", hex));
            return false;
        }

        m_logger.LogInfo(StringFormat("Calibration: %s on %d rows (fp %s)",
                                      modeName, count, hex));

        //--- Experiment manifest (reused per run).
        ExperimentManifest manifest = CExperimentManifest::Create(
            cfg.eaVersion,
            modeName + "_" + hex,
            m_datasetDir,
            0,
            0,
            "SuperCents_X Sprint 14 offline calibration");

        switch(mode)
        {
            case CALIB_MODE_THRESHOLD:
                return RunThreshold(rows, count, cfg, fp, hex, manifest);
            case CALIB_MODE_WEIGHTS:
                return RunWeights(rows, count, cfg, fp, hex, manifest);
            case CALIB_MODE_ABLATION:
                return RunAblation(rows, count, cfg.minConfidence, fp, hex, manifest);
            case CALIB_MODE_PROMOTION:
                return RunPromotion(rows, count, cfg, fp, hex, manifest);
            case CALIB_MODE_ABLATION_CROSSCHECK:
                return RunAblation(rows, count, cfg.minConfidence, fp, hex, manifest, true);
            case CALIB_MODE_CALIBRATION:
                return RunCalibration(rows, count, cfg, fp, hex, manifest);
        }
        return false;
    }

private:
    static string ModeName(ENUM_CALIBRATION_MODE mode)
    {
        switch(mode)
        {
            case CALIB_MODE_THRESHOLD:        return "threshold";
            case CALIB_MODE_WEIGHTS:          return "weights";
            case CALIB_MODE_ABLATION:         return "ablation";
            case CALIB_MODE_PROMOTION:        return "promotion";
            case CALIB_MODE_ABLATION_CROSSCHECK: return "ablation_crosscheck";
            case CALIB_MODE_CALIBRATION:      return "calibration";
        }
        return "unknown";
    }

    static string FpToHex(ulong fp)
    {
        return StringFormat("%016llX", fp);
    }

    static string TimestampTag(void)
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        return StringFormat("%04d%02d%02d_%02d%02d%02d",
                            dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
    }

    static bool WriteCsv(const string filepath, const string header, const string &lines[])
    {
        int handle = FileOpen(filepath, FILE_WRITE | FILE_TXT | FILE_COMMON);
        if(handle == INVALID_HANDLE)
            return false;
        FileWrite(handle, header);
        int n = ArraySize(lines);
        for(int i = 0; i < n; i++)
            FileWrite(handle, lines[i]);
        FileClose(handle);
        return true;
    }

    static bool WriteManifest(const ExperimentManifest &manifest, const string filepath)
    {
        return CExperimentManifest::ToFile(manifest, filepath);
    }

    static bool WriteLines(const string filepath, const string &lines[])
    {
        int handle = FileOpen(filepath, FILE_WRITE | FILE_TXT | FILE_COMMON);
        if(handle == INVALID_HANDLE)
            return false;
        int n = ArraySize(lines);
        for(int i = 0; i < n; i++)
            FileWrite(handle, lines[i]);
        FileClose(handle);
        return true;
    }

    //--- Replay stats for one config on the given rows.
    static void ReplayStats(TelemetryRow &rows[], int count, double threshold, TradeStats &out)
    {
        bool eligible[];
        ArrayResize(eligible, count);
        for(int i = 0; i < count; i++)
            eligible[i] = rows[i].ReplayDecision(threshold);
        CalibrationComputeStats(rows, eligible, count, out);
    }

    bool RunThreshold(TelemetryRow &rows[], int count, const CalibrationConfig &cfg,
                      ulong fp, const string hex, const ExperimentManifest &manifest)
    {
        CThresholdOptimizer optimizer;
        optimizer.Load(rows, count);

        ThresholdResult results[THRESHOLD_OPT_MAX_EVALS];
        int n = optimizer.Optimize(0.40, 0.80, 0.05, cfg.minConfidence, results);

        string lines[];
        ArrayResize(lines, n);
        for(int i = 0; i < n; i++)
        {
            lines[i] = StringFormat("%.2f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%d,%.4f,%d",
                                    results[i].threshold,
                                    results[i].stats.expectancy,
                                    results[i].stats.profitFactor,
                                    results[i].stats.winRate,
                                    results[i].stats.netProfit,
                                    results[i].stats.maxDrawdown,
                                    results[i].stats.recoveryFactor,
                                    results[i].qualifiedSignals,
                                    results[i].settledTrades,
                                    results[i].pValueVsBaseline,
                                    (results[i].significant ? 1 : 0));
        }

        string tag = TimestampTag();
        string reportPath = m_outputDir + "/calib_threshold_" + hex + "_" + tag + ".csv";
        string manifestPath = m_outputDir + "/calib_threshold_" + hex + "_" + tag + ".manifest";
        bool ok = WriteCsv(reportPath,
                           "threshold,expectancy,profitFactor,winRate,netProfit,maxDrawdown,recoveryFactor,qualifiedSignals,settledTrades,pValue,significant",
                           lines);
        ok = WriteManifest(manifest, manifestPath) && ok;

        m_logger.LogInfo(StringFormat("Calibration: threshold sweep wrote %d rows -> %s", n, reportPath));
        m_logger.LogInfo(StringFormat("  Best threshold: %.2f  expectancy %.4f  PF %.4f",
                                      results[0].threshold,
                                      results[0].stats.expectancy,
                                      results[0].stats.profitFactor));
        return ok;
    }

    bool RunWeights(TelemetryRow &rows[], int count, const CalibrationConfig &cfg,
                    ulong fp, const string hex, const ExperimentManifest &manifest)
    {
        CWeightOptimizer optimizer;
        optimizer.Load(rows, count);

        double baseline[TELEMETRY_COMPONENT_COUNT];
        for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
            baseline[i] = cfg.weights[i];

        WeightCandidate best;
        //--- WeightOptimizer threshold is on the 0..100 ReplayConfidence
        //    scale; minConfidence is 0..1, so scale it up.
        int evals = optimizer.Optimize(baseline, cfg.minConfidence * 100.0, best);

        string lines[1];
        lines[0] = StringFormat("%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.4f,%.4f,%.4f,%.4f,%d",
                                best.weights[0], best.weights[1], best.weights[2],
                                best.weights[3], best.weights[4], best.weights[5],
                                best.expectancy, best.profitFactor, best.winRate,
                                best.maxDrawdown, evals);

        string tag = TimestampTag();
        string reportPath = m_outputDir + "/calib_weights_" + hex + "_" + tag + ".csv";
        string manifestPath = m_outputDir + "/calib_weights_" + hex + "_" + tag + ".manifest";
        bool ok = WriteCsv(reportPath,
                           "wStructure,wOB,wFVG,wLiquidity,wTrend,wPD,expectancy,profitFactor,winRate,maxDrawdown,evaluations",
                           lines);
        ok = WriteManifest(manifest, manifestPath) && ok;

        m_logger.LogInfo(StringFormat("Calibration: weight search (%d evals) -> %s", evals, reportPath));
        m_logger.LogInfo(StringFormat("  Best weights: S %.1f  OB %.1f  FVG %.1f  Liq %.1f  Trend %.1f  PD %.1f  expectancy %.4f",
                                      best.weights[0], best.weights[1], best.weights[2],
                                      best.weights[3], best.weights[4], best.weights[5],
                                      best.expectancy));
        return ok;
    }

    bool RunAblation(TelemetryRow &rows[], int count, double threshold,
                     ulong fp, const string hex, const ExperimentManifest &manifest,
                     bool crosscheck = false)
    {
        CValidatorAttribution attribution;
        attribution.Load(rows, count);

        AttributionResult results[ATTR_MAX_VALIDATORS];
        int n = attribution.Analyze(threshold, results);

        string lines[];
        ArrayResize(lines, n);
        for(int i = 0; i < n; i++)
        {
            lines[i] = StringFormat("%s,%d,%.4f,%.4f,%.4f,%d,%.4f,%d,%d",
                                    results[i].validator,
                                    results[i].gateFailCount,
                                    results[i].deltaExpectancy,
                                    results[i].deltaProfitFactor,
                                    results[i].deltaWinRate,
                                    results[i].deltaTrades,
                                    results[i].pValue,
                                    (results[i].recommendWeaken ? 1 : 0),
                                    (results[i].recommendStrengthen ? 1 : 0));
        }

        string mode = crosscheck ? "ablation_crosscheck" : "ablation";
        string tag = TimestampTag();
        string reportPath = m_outputDir + "/calib_" + mode + "_" + hex + "_" + tag + ".csv";
        string manifestPath = m_outputDir + "/calib_" + mode + "_" + hex + "_" + tag + ".manifest";
        bool ok = WriteCsv(reportPath,
                           "validator,gateFailCount,deltaExpectancy,deltaProfitFactor,deltaWinRate,deltaTrades,pValue,recommendWeaken,recommendStrengthen",
                           lines);
        ok = WriteManifest(manifest, manifestPath) && ok;

        m_logger.LogInfo(StringFormat("Calibration: %s (%d validators) -> %s", mode, n, reportPath));
        for(int i = 0; i < n; i++)
        {
            m_logger.LogInfo(StringFormat("  %-22s failGate %5d  dExp %+.4f  dPF %+.3f  p %.3f  %s%s",
                                          results[i].validator,
                                          results[i].gateFailCount,
                                          results[i].deltaExpectancy,
                                          results[i].deltaProfitFactor,
                                          results[i].pValue,
                                          results[i].recommendWeaken ? "[WEAKEN]" : "",
                                          results[i].recommendStrengthen ? "[STRENGTHEN]" : ""));
        }
        return ok;
    }

    bool RunPromotion(TelemetryRow &rows[], int count, const CalibrationConfig &cfg,
                      ulong fp, const string hex, const ExperimentManifest &manifest)
    {
        //--- Candidate stats: replay at the proposed threshold.
        TradeStats candidateStats;
        ReplayStats(rows, count, cfg.minConfidence, candidateStats);

        //--- Baseline stats: production config (0.60 threshold, locked weights).
        TradeStats baselineStats;
        ReplayStats(rows, count, 0.60, baselineStats);

        CPromotionGate gate;
        PromotionReport report;
        bool promoted = gate.Evaluate(rows, count, fp, "candidate@" + cfg.eaVersion,
                                      cfg.minConfidence, 0.60,
                                      candidateStats, baselineStats, report);

        string lines[];
        ArrayResize(lines, report.criterionCount);
        for(int i = 0; i < report.criterionCount; i++)
        {
            string verdictStr = (report.criteria[i].verdict == CRITERION_PASS) ? "PASS"
                : (report.criteria[i].verdict == CRITERION_FAIL) ? "FAIL" : "INCONCLUSIVE";
            lines[i] = StringFormat("%s,%s,%.4f,%.4f,%.4f",
                                    verdictStr, report.criteria[i].name,
                                    report.criteria[i].candidate,
                                    report.criteria[i].baseline,
                                    report.criteria[i].pValue);
        }

        string tag = TimestampTag();
        string reportPath = m_outputDir + "/calib_promotion_" + hex + "_" + tag + ".csv";
        string manifestPath = m_outputDir + "/calib_promotion_" + hex + "_" + tag + ".manifest";
        bool ok = WriteCsv(reportPath,
                           "verdict,criterion,candidate,baseline,pValue",
                           lines);
        ok = WriteManifest(manifest, manifestPath) && ok;

        m_logger.LogInfo(gate.RenderReport(report));
        m_logger.LogInfo(StringFormat("Calibration: promotion report -> %s", reportPath));
        return ok;
    }

    bool RunCalibration(TelemetryRow &rows[], int count, const CalibrationConfig &cfg,
                        ulong fp, const string hex, const ExperimentManifest &manifest)
    {
        //--- Measurement only: no transforms, no thresholds — the raw
        //    confidence distribution over settled rows is the baseline.
        CalibrationBin bins[];
        int binCount = 0;
        CalibrationSummary summary;
        CalibrationAnalyze(rows, count, CALIB_REPORT_DEFAULT_BIN_SIZE, bins, binCount, summary);

        string lines[];
        ArrayResize(lines, binCount);
        for(int i = 0, b = 0; i < ArraySize(bins); i++)
        {
            if(bins[i].trades == 0)
                continue;
            lines[b++] = StringFormat("%.4f,%.4f,%.4f,%d,%d,%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f",
                                      bins[i].binLo, bins[i].binHi, bins[i].center,
                                      bins[i].trades, bins[i].wins, bins[i].losses,
                                      bins[i].scratches, bins[i].winRate, bins[i].expected,
                                      bins[i].absError, bins[i].expectancy,
                                      bins[i].profitFactor, bins[i].maxDrawdown);
        }

        string tag = TimestampTag();
        string reportPath = m_outputDir + "/calib_calibration_" + hex + "_" + tag + ".csv";
        string summaryPath = m_outputDir + "/calib_calibration_" + hex + "_" + tag + ".summary.txt";
        string cardPath = m_outputDir + "/calib_reportcard_" + hex + "_" + tag + ".txt";
        string baselinePath = m_outputDir + "/baseline_calibration_v1.manifest";
        string manifestPath = m_outputDir + "/calib_calibration_" + hex + "_" + tag + ".manifest";

        bool ok = WriteCsv(reportPath,
                           "binLo,binHi,center,trades,wins,losses,scratches,winRate,expected,absError,expectancy,profitFactor,maxDrawdown",
                           lines);

        string summaryLines[];
        ArrayResize(summaryLines, 16);
        summaryLines[0]  = "# Sprint 16.1 confidence measurement baseline";
        summaryLines[1]  = "configFingerprint: " + hex;
        summaryLines[2]  = "datasetFingerprint: " + hex;
        summaryLines[3]  = "eaVersion: " + cfg.eaVersion;
        summaryLines[4]  = "confidenceModel: raw";
        summaryLines[5]  = StringFormat("binSize: %.4f", summary.binSize);
        summaryLines[6]  = StringFormat("totalRows: %d", summary.totalRows);
        summaryLines[7]  = StringFormat("decidedRows: %d", summary.decidedRows);
        summaryLines[8]  = StringFormat("populatedBins: %d", summary.binCount);
        summaryLines[9]  = StringFormat("underpopulatedBins: %d", summary.underpopulatedBins);
        summaryLines[10] = StringFormat("brier: %.6f", summary.brier);
        summaryLines[11] = StringFormat("ece: %.6f", summary.ece);
        summaryLines[12] = StringFormat("mce: %.6f", summary.mce);
        summaryLines[13] = StringFormat("confMin: %.4f", summary.confMin);
        summaryLines[14] = StringFormat("confMax: %.4f", summary.confMax);
        summaryLines[15] = StringFormat("confMean: %.4f  confP50: %.4f  confP90: %.4f",
                                        summary.confMean, summary.confP50, summary.confP90);
        ok = WriteLines(summaryPath, summaryLines) && ok;

        //--- Research report card (plan §5): measurement entry.
        string cardLines[];
        ArrayResize(cardLines, 12);
        cardLines[0]  = "experiment:    calibration_baseline";
        cardLines[1]  = "question:      how well calibrated is the raw v3.0 confidence score?";
        cardLines[2]  = "config fp:     " + hex;
        cardLines[3]  = "dataset fp:    " + hex;
        cardLines[4]  = "eaVersion:     " + cfg.eaVersion;
        cardLines[5]  = "confidenceModel: raw";
        cardLines[6]  = StringFormat("trades:        %d", summary.decidedRows);
        cardLines[7]  = StringFormat("win rate:      %.4f", WinRateOf(rows, count));
        cardLines[8]  = StringFormat("expectancy:    %+.4f", ExpectancyOf(rows, count));
        cardLines[9]  = StringFormat("ece/mce/brier: %.4f / %.4f / %.4f",
                                     summary.ece, summary.mce, summary.brier);
        cardLines[10] = "p vs baseline: n/a (measurement, no comparison)";
        cardLines[11] = "gate verdict:  n/a (baseline frozen, see baseline_calibration_v1.manifest)";
        ok = WriteLines(cardPath, cardLines) && ok;

        //--- Frozen baseline manifest (v1): reference for every future
        //    calibration experiment.  Regenerate only with a version bump.
        string baselineLines[];
        ArrayResize(baselineLines, 11);
        baselineLines[0]  = "# SuperCents_X Sprint 16.1 frozen baseline manifest (v1)";
        baselineLines[1]  = "# Reference for all later calibration experiments. Do not edit.";
        baselineLines[2]  = "configFingerprint: " + hex;
        baselineLines[3]  = "datasetFingerprint: " + hex;
        baselineLines[4]  = "eaVersion: " + cfg.eaVersion;
        baselineLines[5]  = "confidenceModel: raw";
        baselineLines[6]  = StringFormat("binSize: %.4f", summary.binSize);
        baselineLines[7]  = StringFormat("sampleCount: %d", summary.decidedRows);
        baselineLines[8]  = StringFormat("brier: %.6f", summary.brier);
        baselineLines[9]  = StringFormat("ece: %.6f", summary.ece);
        baselineLines[10] = StringFormat("mce: %.6f", summary.mce);
        ok = WriteLines(baselinePath, baselineLines) && ok;

        ok = WriteManifest(manifest, manifestPath) && ok;

        m_logger.LogInfo(StringFormat("Calibration: measurement baseline (%d populated bins) -> %s",
                                      binCount, reportPath));
        m_logger.LogInfo(StringFormat("  decided %d / %d rows  Brier %.6f  ECE %.6f  MCE %.6f",
                                      summary.decidedRows, summary.totalRows,
                                      summary.brier, summary.ece, summary.mce));
        return ok;
    }

    static double WinRateOf(TelemetryRow &rows[], int count)
    {
        int wins = 0;
        int losses = 0;
        for(int i = 0; i < count; i++)
        {
            if(rows[i].outcome == (int)TELEMETRY_OUTCOME_WIN)
                wins++;
            else if(rows[i].outcome == (int)TELEMETRY_OUTCOME_LOSS)
                losses++;
        }
        int decided = wins + losses;
        return (decided > 0) ? (double)wins / (double)decided : 0.0;
    }

    static double ExpectancyOf(TelemetryRow &rows[], int count)
    {
        double sum = 0.0;
        int n = 0;
        for(int i = 0; i < count; i++)
        {
            if(rows[i].outcome == (int)TELEMETRY_OUTCOME_UNKNOWN)
                continue;
            sum += rows[i].rMultiple;
            n++;
        }
        return (n > 0) ? sum / (double)n : 0.0;
    }

    CLogger             m_logger;
    string              m_datasetDir;
    string              m_outputDir;
    CCalibrationDataset m_dataset;
};

#endif



