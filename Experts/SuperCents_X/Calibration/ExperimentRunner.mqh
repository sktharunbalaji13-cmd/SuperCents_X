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
//    CALIB_MODE_TRANSFORMS       - Branch A model comparison (16.2)
//    CALIB_MODE_STRUCTURAL       - structural diagnostics (16.1B)
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
#include "CalibrationTransforms.mqh"
#include "CalibrationStructural.mqh"
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
    CALIB_MODE_CALIBRATION,
    CALIB_MODE_TRANSFORMS,
    CALIB_MODE_STRUCTURAL
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
            case CALIB_MODE_TRANSFORMS:
                return RunTransforms(rows, count, cfg, fp, hex, manifest);
            case CALIB_MODE_STRUCTURAL:
                return RunStructural(rows, count, cfg, fp, hex, manifest);
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
            case CALIB_MODE_TRANSFORMS:       return "transforms";
            case CALIB_MODE_STRUCTURAL:       return "structural";
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
            if(StringLen(lines[i]) > 0)
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

    bool RunTransforms(TelemetryRow &rows[], int count, const CalibrationConfig &cfg,
                       ulong fp, const string hex, const ExperimentManifest &manifest)
    {
        //--- Raw baseline metrics (self-contained, mirrors the frozen v1 manifest).
        CalibrationBin rawBins[];
        int rawBinCount = 0;
        CalibrationSummary rawSummary;
        CalibrationAnalyze(rows, count, CALIB_REPORT_DEFAULT_BIN_SIZE, rawBins, rawBinCount, rawSummary);

        TradeStats baselineStats;
        ReplayStats(rows, count, 0.60, baselineStats);

        const int modelTypes[3] =
        {
            CALIB_TRANSFORM_ISOTONIC_V1,
            CALIB_TRANSFORM_PLATT_V1,
            CALIB_TRANSFORM_TEMPERATURE_V1
        };

        string tag = TimestampTag();
        string lines[4];
        int row = 0;

        lines[row++] = StringFormat("raw,%.6f,0.000000,%.6f,0.000000,%.6f,%d,%.4f,%.4f,%.4f,%.4f,1.000000,0",
                                    rawSummary.ece, rawSummary.brier, rawSummary.mce,
                                    baselineStats.trades, baselineStats.expectancy,
                                    baselineStats.profitFactor, baselineStats.winRate,
                                    baselineStats.maxDrawdown);

        for(int m = 0; m < 3; m++)
        {
            string name = CalibrationTransformName(modelTypes[m]);

            CalibrationTransformParams params;
            if(!CalibrationFitTransform(modelTypes[m], rows, count, params))
            {
                m_logger.LogWarn(StringFormat("Calibration: %s fit failed", name));
                lines[row++] = StringFormat("%s,failed,0.0,0.0,0.0,0.0,0,0.0,0.0,0.0,0.0,1.000000,0",
                                            name);
                continue;
            }

            //--- Transformed copy: ReplayDecision reads row.confidence, so a
            //    scored copy lets every downstream tool (report, gate) run
            //    unchanged on the calibrated score.
            TelemetryRow trows[];
            ArrayResize(trows, count);
            for(int i = 0; i < count; i++)
            {
                trows[i] = rows[i];
                trows[i].confidence = CalibrationTransformApply(rows[i].confidence, params);
            }

            CalibrationBin bins[];
            int binCount = 0;
            CalibrationSummary summary;
            CalibrationAnalyze(trows, count, CALIB_REPORT_DEFAULT_BIN_SIZE, bins, binCount, summary);

            bool eligible[];
            ArrayResize(eligible, count);
            for(int i = 0; i < count; i++)
                eligible[i] = trows[i].ReplayDecision(0.60);
            TradeStats candidateStats;
            CalibrationComputeStats(trows, eligible, count, candidateStats);

            CPromotionGate gate;
            PromotionReport report;
            bool promoted = gate.Evaluate(trows, count, fp, name + "@0.60",
                                          0.60, 0.60, candidateStats, baselineStats, report);
            double pVal = (report.criterionCount > 3) ? report.criteria[3].pValue : 1.0;

            string plines[];
            CalibrationTransformSerialize(params, plines);
            string paramsPath = m_outputDir + "/calib_transform_" + name + "_" + hex + "_" + tag + ".params";
            WriteLines(paramsPath, plines);

            lines[row++] = StringFormat("%s,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%d",
                                        name, summary.ece, rawSummary.ece - summary.ece,
                                        summary.brier, rawSummary.brier - summary.brier,
                                        summary.mce, candidateStats.trades,
                                        candidateStats.expectancy, candidateStats.profitFactor,
                                        candidateStats.winRate, candidateStats.maxDrawdown,
                                        pVal, (promoted ? 1 : 0));

            m_logger.LogInfo(StringFormat("Calibration: %-14s ECE %.4f (d%+.4f)  Brier %.4f (d%+.4f)  trades@0.60 %d  promoted %d",
                                          name, summary.ece, rawSummary.ece - summary.ece,
                                          summary.brier, rawSummary.brier - summary.brier,
                                          candidateStats.trades, (promoted ? 1 : 0)));
        }

        string reportPath = m_outputDir + "/calib_transforms_" + hex + "_" + tag + ".csv";
        string manifestPath = m_outputDir + "/calib_transforms_" + hex + "_" + tag + ".manifest";
        string cardPath = m_outputDir + "/calib_reportcard_" + hex + "_" + tag + ".txt";

        bool ok = WriteCsv(reportPath,
                           "model,ece,deltaEce,brier,deltaBrier,mce,trades060,expectancy,profitFactor,winRate,maxDrawdown,pExpectancy,promoted",
                           lines);

        string cardLines[];
        ArrayResize(cardLines, 12);
        cardLines[0]  = "experiment:    calibration_transforms_compare";
        cardLines[1]  = "question:      which Branch A transform best calibrates the raw v3.0 score?";
        cardLines[2]  = "config fp:     " + hex;
        cardLines[3]  = "dataset fp:    " + hex;
        cardLines[4]  = "eaVersion:     " + cfg.eaVersion;
        cardLines[5]  = "confidenceModel: raw (reference) / isotonic_v1 / platt_v1 / temperature_v1";
        cardLines[6]  = StringFormat("raw baseline:  ECE %.6f  Brier %.6f  MCE %.6f",
                                     rawSummary.ece, rawSummary.brier, rawSummary.mce);
        cardLines[7]  = "models:        see calib_transforms_<hex>_<tag>.csv (Calibration Gain table)";
        cardLines[8]  = "params:        calib_transform_<model>_<hex>_<tag>.params (reproducible, invertible)";
        cardLines[9]  = "gate:          each model replayed at 0.60 vs raw baseline (PromotionGate criteria)";
        cardLines[10] = "decision:      select model with best Calibration Gain; then rerun gate in 16.5";
        cardLines[11] = "note:          fits are in-sample; selection confirmed by 16.5 gate before adoption";
        ok = WriteLines(cardPath, cardLines) && ok;
        ok = WriteManifest(manifest, manifestPath) && ok;

        m_logger.LogInfo(StringFormat("Calibration: transform comparison -> %s", reportPath));
        return ok;
    }

    bool RunStructural(TelemetryRow &rows[], int count, const CalibrationConfig &cfg,
                       ulong fp, const string hex, const ExperimentManifest &manifest)
    {
        //--- Evidence availability (Sprint 17 contract): schema v3 rows
        //    carry rule/layer evidence (componentData == 1); the legacy
        //    6-component columns are a SEPARATE model that v3.0 never
        //    computes.  Sections A/B/D are legacy-basis (they key off the
        //    legacy columns); they are gated on legacy raws existing.
        //    The v3-aware (layer-basis) report is Sprint 17 step 8.
        int componentRows = 0;    // rows carrying v3 evidence
        int legacyRawRows = 0;    // rows carrying legacy component raws
        for(int i = 0; i < count; i++)
        {
            if(rows[i].schemaVersion >= 3 && rows[i].componentData == 1)
                componentRows++;
            bool anyLegacy = false;
            for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
            {
                if(CalibrationStructuralActive(rows[i], c))
                {
                    anyLegacy = true;
                    break;
                }
            }
            if(anyLegacy)
                legacyRawRows++;
        }
        bool haveComponents = (componentRows > 0);   // v3 evidence basis
        bool haveLegacyRaws = (legacyRawRows > 0);   // sections A/B/D basis

        //--- Section C: rank correlations (always computed; conf-level rows
        //    are the primary evidence).
        StructuralCorrelation corr[];
        CalibrationStructuralCorrelations(rows, count, corr);

        string lines[];
        int nLines = 0;
        ArrayResize(lines, 3 * TELEMETRY_COMPONENT_COUNT + CALIB_STRUCT_MAX_FIRED
                    + ArraySize(corr) + TELEMETRY_COMPONENT_COUNT + 3);

        string dash = "-";
        if(haveLegacyRaws)
        {
            //--- Section A: activation + marginal predictive power.
            StructuralComponentStat comps[];
            CalibrationStructuralComponents(rows, count, comps);

            //--- Section B: fired-count decomposition.
            StructuralFiredCount fired[];
            CalibrationStructuralFiredCounts(rows, count, fired);

            //--- Section D: information contribution (ablation replay at gate).
            StructuralAblation abl[];
            CalibrationStructuralAblation(rows, count, 0.60, abl);

            //--- Section A rows: activation + absent + present per component.
            for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
            {
                StructuralComponentStat s = comps[c];
                lines[nLines++] = StringFormat("A,%s_activation,%.4f,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s",
                                               s.name, s.activationPct,
                                               dash, dash, dash, dash, dash, dash, dash, dash, dash, dash, dash);
                lines[nLines++] = StringFormat("A,%s_absent,%.4f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%s,%s,%s,%s",
                                               s.name, s.activationPct,
                                               s.absentTrades, s.absentWinRate,
                                               s.absentProfitFactor, s.absentExpectancy,
                                               s.absentMeanConf, s.absentMeanR,
                                               dash, dash, dash, dash, dash);
                lines[nLines++] = StringFormat("A,%s_present,%.4f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%s,%s,%s,%s",
                                               s.name, s.activationPct,
                                               s.presentTrades, s.presentWinRate,
                                               s.presentProfitFactor, s.presentExpectancy,
                                               s.presentMeanConf, s.presentMeanR,
                                               dash, dash, dash, dash, dash);
            }

            //--- Section B rows.
            for(int g = 0; g < CALIB_STRUCT_MAX_FIRED; g++)
            {
                StructuralFiredCount fc = fired[g];
                lines[nLines++] = StringFormat("B,%d,%.4f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%s,%s,%s,%s",
                                               fc.fired, dash,
                                               fc.trades, fc.winRate, fc.profitFactor,
                                               fc.expectancy, fc.meanConf, fc.meanR,
                                               dash, dash, dash, dash, dash);
            }

            //--- Section D rows.
            for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
            {
                StructuralAblation a = abl[c];
                lines[nLines++] = StringFormat("D,%s,%s,%s,%s,%s,%s,%s,%s,%.4f,%.4f,%.4f,%.4f,%d",
                                               a.name,
                                               dash, dash, dash, dash, dash, dash, dash,
                                               a.deltaExp, a.deltaPF, a.deltaTrades, a.infoContrib,
                                               a.component);
            }
        }
        else
        {
            //--- Data gap: legacy-basis sections need legacy component raws.
            //    v2 datasets never recorded the v3.0 engine's components and
            //    v3.0 rows carry the rule-layer evidence elsewhere (the
            //    layer-basis report is Sprint 17 step 8); per-component
            //    correlations would be artifacts of all-zero arrays.
            lines[nLines++] = "A,data_gap,0.0000,-,-,-,-,-,-,-,-,-,-,-";
            lines[nLines++] = "B,data_gap,0.0000,-,-,-,-,-,-,-,-,-,-,-";
            lines[nLines++] = "D,data_gap,0.0000,-,-,-,-,-,-,-,-,-,-,-";
        }

        //--- Section C rows: conf-level correlations always; per-component
        //    Spearman only when legacy raw scores are available.
        for(int i = 0; i < ArraySize(corr); i++)
        {
            if(!haveLegacyRaws && StringFind(corr[i].label, "spearman_") == 0
               && StringFind(corr[i].label, "spearman_conf") != 0)
                continue;
            lines[nLines++] = StringFormat("C,%s,%s,%s,%s,%s,%s,%s,%s,%.4f,%s,%s,%s,%s,%d",
                                           corr[i].label,
                                           dash, dash, dash, dash, dash, dash, dash,
                                           corr[i].value,
                                           dash, dash, dash, dash, corr[i].n);
        }

        string tag = TimestampTag();
        string reportPath = m_outputDir + "/calib_structural_" + hex + "_" + tag + ".csv";
        string manifestPath = m_outputDir + "/calib_structural_" + hex + "_" + tag + ".manifest";
        string cardPath = m_outputDir + "/calib_reportcard_" + hex + "_" + tag + ".txt";

        bool ok = WriteCsv(reportPath,
                           "section,key,activationPct,trades,winRate,profitFactor,expectancy,meanConf,meanR,value,deltaExp,deltaPF,deltaTrades,infoContrib,n",
                           lines);

        string cardLines[];
        ArrayResize(cardLines, 14);
        cardLines[0]  = "experiment:    calibration_structural (16.1B)";
        cardLines[1]  = "question:      why is the raw v3.0 confidence ordering weak/anti-correlated?";
        cardLines[2]  = "config fp:     " + hex;
        cardLines[3]  = "dataset fp:    " + hex;
        cardLines[4]  = "eaVersion:     " + cfg.eaVersion;
        cardLines[5]  = "confidenceModel: raw (structure analysis, no transforms)";
        cardLines[6]  = "sections:      A activation+marginal | B fired-count | C rank corr | D ablation";
        cardLines[7]  = StringFormat("gate:          ablation replayed at %.2f (PromotionGate replay)", 0.60);
        cardLines[8]  = StringFormat("trades:        %d (decided) / %d (total)",
                                     count - ScratchesAndUnknownOf(rows, count), count);
        cardLines[9]  = "decision:      root-cause confidence generation; no calibration adopted in 16.2";
        cardLines[10] = "note:          rank correlations are the primary evidence (ordering strength)";
        cardLines[11] = "note:          sections are descriptive; no gate decision is implied";
        cardLines[12] = haveComponents
                        ? StringFormat("components:    present in %d rows (schema v3 evidence); legacy-basis sections A/B/D %s", componentRows,
                                       (haveLegacyRaws ? "computed" : "data_gap (rule-layer basis lands in Sprint 17 step 8)"))
                        : StringFormat("components:    MISSING (0 of %d rows carry v3.0 evidence; v2 schema records only the legacy confluence engine - sections A/B/D skipped; per-component correlations suppressed as constant-array artifacts)", count);
        cardLines[13] = "next:          16.5 gate re-anchor on calibrated scores (deferred)";
        ok = WriteLines(cardPath, cardLines) && ok;
        ok = WriteManifest(manifest, manifestPath) && ok;

        m_logger.LogInfo(StringFormat("Calibration: structural report -> %s", reportPath));
        for(int i = 0; i < ArraySize(corr); i++)
        {
            m_logger.LogInfo(StringFormat("  %-22s %+.4f  (n=%d)",
                                          corr[i].label, corr[i].value, corr[i].n));
        }
        return ok;
    }

    static int ScratchesAndUnknownOf(TelemetryRow &rows[], int count)
    {
        int n = 0;
        for(int i = 0; i < count; i++)
        {
            if(rows[i].outcome != (int)TELEMETRY_OUTCOME_WIN &&
               rows[i].outcome != (int)TELEMETRY_OUTCOME_LOSS)
                n++;
        }
        return n;
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



