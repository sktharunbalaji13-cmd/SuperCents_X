//+------------------------------------------------------------------+
//|                                       TelemetryHealthReport.mqh   |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 17 (v3.1)      |
//+------------------------------------------------------------------+
//  Schema Health Gate — validates that a telemetry dataset is
//  structurally trustworthy before downstream analysis consumes it.
//
//  Position in the research pipeline:
//    Telemetry Collection -> Schema Health Gate -> Structural
//    Diagnostics -> Architecture Research -> Calibration -> Promotion
//
//  This gate answers ONE question:
//    "Is this telemetry dataset structurally trustworthy enough
//     to use downstream?"
//
//  It does NOT evaluate strategy quality (expectancy, PF, drawdown).
//  Those belong to Calibration, Structural Diagnostics, and the
//  Promotion Gate.
//
//  Health score weights are constants (not hard-coded inline) so the
//  scoring model can be tuned without touching the analyzer.
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_HEALTH_REPORT_MQH__
#define __TELEMETRY_HEALTH_REPORT_MQH__

#include "TelemetryTypes.mqh"
#include "CalibrationDataset.mqh"

//--- Health report format version (independent of telemetry schema).
#define HEALTH_REPORT_VERSION  1

//--- Default round-trip sample size (configurable at call time).
#define DEFAULT_ROUNDTRIP_SAMPLE 100

//--- Health score weights (sum = 100).
#define HEALTH_WEIGHT_SCHEMA_VERSION    15
#define HEALTH_WEIGHT_PARSE_SUCCESS     15
#define HEALTH_WEIGHT_COMPONENT_COVERAGE 15
#define HEALTH_WEIGHT_MISSING_LAYERS    10
#define HEALTH_WEIGHT_MISSING_EVIDENCE  10
#define HEALTH_WEIGHT_MISSING_MARKERS   10
#define HEALTH_WEIGHT_ROUND_TRIP        15
#define HEALTH_WEIGHT_LEGACY_CONSIST    10

//--- Verdict thresholds.
#define HEALTH_VERDICT_PASS_THRESHOLD  95
#define HEALTH_VERDICT_WARN_THRESHOLD  80

//--- Maximum rules / evidence combos tracked.
#define HEALTH_MAX_RULES  16
#define HEALTH_MAX_COMBOS 256

//+------------------------------------------------------------------+
//| Verdict enum — strings only at report time.                      |
//+------------------------------------------------------------------+
enum ENUM_HEALTH_VERDICT
{
    HEALTH_FAIL = 0,
    HEALTH_WARN,
    HEALTH_PASS,
    HEALTH_NA       // check not applicable (e.g. no component rows)
};

//+------------------------------------------------------------------+
//| Parse health: row-level parsing outcomes.                        |
//+------------------------------------------------------------------+
struct ParseHealth
{
    int totalRows;          // every non-blank line scanned
    int parsedRows;         // rows that parsed successfully
    int schemaFailures;     // refused: unsupported schemaVersion
    int csvFailures;        // refused: column-count mismatch / malformed
    int unknownFailures;    // refused: other (blank, corrupt)
    int unexpectedEnumCount;// rows with enum values outside valid ranges
    double parseSuccessRate;// parsedRows / totalRows

    ParseHealth(void)
        : totalRows(0)
        , parsedRows(0)
        , schemaFailures(0)
        , csvFailures(0)
        , unknownFailures(0)
        , unexpectedEnumCount(0)
        , parseSuccessRate(0.0)
    {}
};

//+------------------------------------------------------------------+
//| Schema health: structural integrity checks.                      |
//+------------------------------------------------------------------+
struct SchemaHealth
{
    int    schemaVersionCounts[10];  // count per schemaVersion (index = version)
    bool   schemaVersionPass;        // 100% v3
    bool   legacyConsistencyPass;    // v3 rows have zero legacy raws; v2 rows have them
    bool   roundTripPass;            // serialize -> parse -> serialize -> parse equal
    int    roundTripSampleSize;      // rows sampled for round-trip
    int    roundTripFailures;        // rows that failed round-trip
    int    missingMarkerCount;       // literal "MISSING" occurrences
    bool   coverageApplicable;       // false if no component rows exist

    SchemaHealth(void)
        : schemaVersionPass(false)
        , legacyConsistencyPass(false)
        , roundTripPass(false)
        , roundTripSampleSize(0)
        , roundTripFailures(0)
        , missingMarkerCount(0)
        , coverageApplicable(false)
    {
        ArrayInitialize(schemaVersionCounts, 0);
    }
};

//+------------------------------------------------------------------+
//| Per-rule coverage entry.                                         |
//+------------------------------------------------------------------+
struct RuleCoverageEntry
{
    int    ruleId;
    string ruleName;
    int    totalRows;       // rows with this firedRuleId
    int    componentRows;   // rows with componentData == 1
    double coveragePct;     // componentRows / totalRows

    RuleCoverageEntry(void)
        : ruleId(0)
        , ruleName("")
        , totalRows(0)
        , componentRows(0)
        , coveragePct(0.0)
    {}
};

//+------------------------------------------------------------------+
//| Component health: evidence coverage.                             |
//+------------------------------------------------------------------+
struct ComponentHealth
{
    int    componentDataRows;    // rows with componentData == 1
    int    decidedRows;          // rows with settled outcome
    int    missingLayerRows;     // componentData==1 but layerTotal == 0
    int    missingEvidenceRows;  // componentData==1 but all flags == EV_UNKNOWN
    double componentCoverage;    // componentDataRows / decidedRows

    //--- Per-flag coverage (fraction of component rows where flag != EV_UNKNOWN).
    double flagCoverageBOS;
    double flagCoverageCHOCH;
    double flagCoverageOrderBlock;
    double flagCoverageFVG;
    double flagCoverageProtectedPoint;
    double flagCoverageLiquiditySweep;

    //--- Per-rule coverage.
    RuleCoverageEntry ruleCoverage[HEALTH_MAX_RULES];
    int    ruleCount;

    //--- Distinct evidence combinations.
    int    distinctEvidenceCombos;

    ComponentHealth(void)
        : componentDataRows(0)
        , decidedRows(0)
        , missingLayerRows(0)
        , missingEvidenceRows(0)
        , componentCoverage(0.0)
        , flagCoverageBOS(0.0)
        , flagCoverageCHOCH(0.0)
        , flagCoverageOrderBlock(0.0)
        , flagCoverageFVG(0.0)
        , flagCoverageProtectedPoint(0.0)
        , flagCoverageLiquiditySweep(0.0)
        , ruleCount(0)
        , distinctEvidenceCombos(0)
    {}
};

//+------------------------------------------------------------------+
//| Layer distribution (per layer: min / mean / max).                |
//+------------------------------------------------------------------+
struct LayerHealth
{
    int    layerStructuralMin;
    double layerStructuralMean;
    int    layerStructuralMax;
    int    layerLiquidityMin;
    double layerLiquidityMean;
    int    layerLiquidityMax;
    int    layerConfirmationMin;
    double layerConfirmationMean;
    int    layerConfirmationMax;
    int    layerTotalMin;
    double layerTotalMean;
    int    layerTotalMax;

    LayerHealth(void)
        : layerStructuralMin(0)
        , layerStructuralMean(0.0)
        , layerStructuralMax(0)
        , layerLiquidityMin(0)
        , layerLiquidityMean(0.0)
        , layerLiquidityMax(0)
        , layerConfirmationMin(0)
        , layerConfirmationMean(0.0)
        , layerConfirmationMax(0)
        , layerTotalMin(0)
        , layerTotalMean(0.0)
        , layerTotalMax(0)
    {}
};

//+------------------------------------------------------------------+
//| Top-level health report.                                         |
//+------------------------------------------------------------------+
struct TelemetryHealthReport
{
    ParseHealth      parse;
    SchemaHealth     schema;
    ComponentHealth  components;
    LayerHealth      layers;

    int              healthScore;       // 0-100
    ENUM_HEALTH_VERDICT verdict;
    string           verdictReason;     // human-readable breakdown

    TelemetryHealthReport(void)
        : healthScore(0)
        , verdict(HEALTH_FAIL)
        , verdictReason("")
    {}
};

//+------------------------------------------------------------------+
//| Health report analyzer.                                          |
//+------------------------------------------------------------------+
class CTelemetryHealthAnalyzer
{
private:
    //--- Track distinct evidence combos (simple linear scan; bounded).
    string m_combos[HEALTH_MAX_COMBOS];
    int    m_comboCount;

    //--- Track per-rule counts during the single pass.
    int    m_ruleIds[HEALTH_MAX_RULES];
    string m_ruleNames[HEALTH_MAX_RULES];
    int    m_ruleTotals[HEALTH_MAX_RULES];
    int    m_ruleComponents[HEALTH_MAX_RULES];
    int    m_ruleEntryCount;

    bool RegisterCombo(const string combo)
    {
        for(int i = 0; i < m_comboCount; i++)
            if(m_combos[i] == combo)
                return true;
        if(m_comboCount < HEALTH_MAX_COMBOS)
        {
            m_combos[m_comboCount] = combo;
            m_comboCount++;
            return true;
        }
        return false; // overflow — count is capped
    }

    bool RegisterRule(int ruleId, const string ruleName, bool hasComponent)
    {
        for(int i = 0; i < m_ruleEntryCount; i++)
        {
            if(m_ruleIds[i] == ruleId)
            {
                m_ruleTotals[i]++;
                if(hasComponent)
                    m_ruleComponents[i]++;
                return true;
            }
        }
        if(m_ruleEntryCount < HEALTH_MAX_RULES)
        {
            m_ruleIds[m_ruleEntryCount] = ruleId;
            m_ruleNames[m_ruleEntryCount] = ruleName;
            m_ruleTotals[m_ruleEntryCount] = 1;
            m_ruleComponents[m_ruleEntryCount] = hasComponent ? 1 : 0;
            m_ruleEntryCount++;
            return true;
        }
        return false;
    }

    //--- Check for unexpected enum values (corruption detector).
    static bool HasUnexpectedEnum(const TelemetryRow &row)
    {
        //--- direction: 0 (NONE), 1 (BULLISH), 2 (BEARISH)
        if(row.direction < 0 || row.direction > 2)
            return true;
        //--- outcome: 0 (UNKNOWN), 1 (WIN), 2 (LOSS), 3 (BREAKEVEN)
        if(row.outcome < 0 || row.outcome > 3)
            return true;
        //--- outcomeSource: 0 (NONE), 1 (SIMULATED), 2 (ACTUAL)
        if(row.outcomeSource < 0 || row.outcomeSource > 2)
            return true;
        //--- exitReason: 0-4
        if(row.exitReason < 0 || row.exitReason > 4)
            return true;
        //--- firedRuleId: 0 (NONE) .. 7 (CHOCH_OB_REVERSAL)
        if(row.firedRuleId < 0 || row.firedRuleId > 7)
            return true;
        //--- tristate flags: 0 (UNKNOWN), 1 (FALSE), 2 (TRUE)
        if(row.hasBOS < 0 || row.hasBOS > 2) return true;
        if(row.hasCHOCH < 0 || row.hasCHOCH > 2) return true;
        if(row.hasOrderBlock < 0 || row.hasOrderBlock > 2) return true;
        if(row.hasFVG < 0 || row.hasFVG > 2) return true;
        if(row.hasProtectedPoint < 0 || row.hasProtectedPoint > 2) return true;
        if(row.hasLiquiditySweep < 0 || row.hasLiquiditySweep > 2) return true;
        if(row.trendAligned < 0 || row.trendAligned > 2) return true;
        return false;
    }

    //--- Check for literal "MISSING" in string fields.
    static int CountMissingMarkers(const TelemetryRow &row)
    {
        int count = 0;
        if(StringFind(row.symbol, "MISSING") >= 0) count++;
        if(StringFind(row.eaVersion, "MISSING") >= 0) count++;
        if(StringFind(row.disabledValidators, "MISSING") >= 0) count++;
        if(StringFind(row.ruleName, "MISSING") >= 0) count++;
        if(StringFind(row.ruleEvidenceIds, "MISSING") >= 0) count++;
        if(StringFind(row.scoreArchitecture, "MISSING") >= 0) count++;
        if(StringFind(row.telemetryArchitecture, "MISSING") >= 0) count++;
        if(StringFind(row.evidenceContract, "MISSING") >= 0) count++;
        if(StringFind(row.confidenceModel, "MISSING") >= 0) count++;
        return count;
    }

    //--- Legacy consistency (TC02 wiring contract):
    //    v2 rows — populated by the legacy engine; unchecked here.
    //    v3 rows (pre-wiring files) — componentData==1 rows must NOT
    //        carry legacy raws (the v3.0 engine never computed them).
    //    v4 rows (post-wiring) — componentData==1 rows must satisfy one
    //        of the two split invariants against the layer decomposition
    //        the engine stamped on the same row.
    static bool LegacyRowConsistent(const TelemetryRow &row)
    {
        if(row.schemaVersion <= 3 && row.componentData == 1)
        {
            //--- v3 evidence rows: legacy raws should all be zero.
            if(MathAbs(row.structureRaw) > 1e-9) return false;
            if(MathAbs(row.obRaw) > 1e-9) return false;
            if(MathAbs(row.fvgRaw) > 1e-9) return false;
            if(MathAbs(row.trendRaw) > 1e-9) return false;
            if(MathAbs(row.liquidityRaw) > 1e-9) return false;
            if(MathAbs(row.pdRaw) > 1e-9) return false;
        }
        else if(row.schemaVersion >= 4 && row.componentData == 1)
        {
            if(!SplitConsistent(row))
                return false;
        }
        return true;
    }

    //--- TC02 split invariants.  A v4 row is consistent when either
    //    (a) rule path: the raw slices sum to the layer split, each
    //        slice matches the layer the engine computed, and each
    //        component obeys contribution == score * weight / 100 (the
    //        BuildRuleComponents formula), or
    //    (b) evaluator path: the contribution slices rebuild the layers
    //        (CConfluenceEngine::BridgeConfluenceToSignal truncates
    //        contributions to ints when rebuilding the score layers).
    static bool SplitConsistent(const TelemetryRow &row)
    {
        const double tol = 1e-6;

        //--- (a) Rule path: raw slices == layer split.
        if(MathAbs(row.structureRaw + row.obRaw + row.fvgRaw - (double)row.layerStructural) <= tol &&
           MathAbs(row.obRaw - (double)row.layerOrderBlock) <= tol &&
           MathAbs(row.fvgRaw - (double)row.layerFVG) <= tol &&
           MathAbs(row.liquidityRaw - (double)row.layerLiquidity) <= tol &&
           MathAbs(row.pdRaw) <= tol &&
           MathAbs(row.structureContribution - row.structureRaw * row.structureWeight / 100.0) <= tol &&
           MathAbs(row.obContribution - row.obRaw * row.obWeight / 100.0) <= tol &&
           MathAbs(row.fvgContribution - row.fvgRaw * row.fvgWeight / 100.0) <= tol &&
           MathAbs(row.liquidityContribution - row.liquidityRaw * row.liquidityWeight / 100.0) <= tol &&
           MathAbs(row.trendContribution - row.trendRaw * row.trendWeight / 100.0) <= tol &&
           ((row.trendAligned == (int)EV_TRUE && row.trendRaw > 0.0) ||
            (row.trendAligned != (int)EV_TRUE && MathAbs(row.trendRaw) <= tol)))
            return true;

        //--- (b) Evaluator path: contribution slices == layer split.
        if((int)row.structureContribution + (int)row.obContribution + (int)row.fvgContribution == row.layerStructural &&
           (int)row.obContribution == row.layerOrderBlock &&
           (int)row.fvgContribution == row.layerFVG &&
           (int)row.liquidityContribution == row.layerLiquidity &&
           (int)row.trendContribution + (int)row.pdContribution == row.layerConfirmation)
            return true;

        return false;
    }

public:
    //--- Serialize a row to CSV (mirrors TelemetryCollector::WriteRow).
    //--- Serialize one row for round-trip auditing.  Schema v5 rows
    //    carry the 3 swing-gate columns (append-only over v3.1); legacy
    //    rows re-serialize byte-identically to their original shape.
    static string SerializeRow(const TelemetryRow &row)
    {
        int    v5QualifyingId = 0;
        double v5Amplitude    = 0.0;
        string v5Decision     = "OFF";
        if(row.schemaVersion >= 5)
        {
            v5QualifyingId = row.swingQualifyingId;
            v5Amplitude    = row.swingAmplitude;
            v5Decision     = row.gateDecision;
        }
        return StringFormat(
            "%d,%llu,%s,%s,%d,%s,%d,%d,%.8f,"
            "%.8f,%.6f,%.8f,%.8f,%.6f,%.8f,%.8f,%.6f,%.8f,"
            "%.8f,%.6f,%.8f,%.8f,%.6f,%.8f,%.8f,%.6f,%.8f,"
            "%s,%.6f,%d,%d,%d,%d,%.8f,%.8f,%s,"
            "%d,%d,%.8f,%d,%d,%.8f,%.8f,"
            "%d,%d,"
            "%s,%s,%s,%s,%d,"
            "%d,%s,%d,%.8f,%d,\"%s\",%d,"
            "%d,%d,%d,%d,"
            "%d,%d,%d,%d,%d,%d,"
            "%s,"
            "%d,%d,%s,%s,%s,%s,%s,"
            "%d,%.8f,%s",
            (int)row.schemaVersion,
            (ulong)row.configFingerprint,
            TimeToString(row.timestamp),
            row.symbol,
            row.timeframe,
            row.eaVersion,
            row.decisionId,
            row.direction,
            row.confidence,
            row.structureRaw, row.structureWeight, row.structureContribution,
            row.obRaw,        row.obWeight,        row.obContribution,
            row.fvgRaw,       row.fvgWeight,       row.fvgContribution,
            row.trendRaw,     row.trendWeight,     row.trendContribution,
            row.liquidityRaw, row.liquidityWeight, row.liquidityContribution,
            row.pdRaw,        row.pdWeight,        row.pdContribution,
            row.PackValidatorResults(),
            row.confThreshold,
            (row.newDecision ? 1 : 0),
            (row.legacyDecision ? 1 : 0),
            (row.decisionMatch ? 1 : 0),
            (row.directionMatch ? 1 : 0),
            row.legacyConfidence,
            row.newConfidence,
            ToPipedList(row.disabledValidators),
            row.outcomeSource,
            row.outcome,
            row.rMultiple,
            row.barsHeld,
            row.exitReason,
            row.entryPrice,
            row.exitPrice,
            row.actualOutcome,
            row.actualOutcomeSource,
            row.scoreArchitecture,
            row.telemetryArchitecture,
            row.evidenceContract,
            row.confidenceModel,
            row.componentData,
            row.firedRuleId,
            row.ruleName,
            row.ruleScore,
            row.ruleConfidence,
            row.ruleEvidenceCount,
            row.ruleEvidenceIds,
            row.trendAligned,
            row.layerStructural,
            row.layerLiquidity,
            row.layerConfirmation,
            row.layerTotal,
            row.hasBOS,
            row.hasCHOCH,
            row.hasOrderBlock,
            row.hasFVG,
            row.hasProtectedPoint,
            row.hasLiquiditySweep,
            TimeToString(row.signalTime),
            //--- Schema v3.1 evidence columns (append-only over v3).
            row.layerOrderBlock,
            row.layerFVG,
            row.fvgClass,
            row.fvgSize,
            row.fvgStrength,
            TimeToString(row.fvgCreatedTime),
            TimeToString(row.fvgFillTime),
            //--- Schema v5 swing-gate columns (append-only over v3.1).
            v5QualifyingId,
            v5Amplitude,
            v5Decision);
    }

private:
    static string ToPipedList(const string commaList)
    {
        if(commaList == "")
            return "";
        string parts[];
        int n = StringSplit(commaList, ',', parts);
        string out = "";
        for(int i = 0; i < n; i++)
        {
            string t = parts[i];
            StringTrimLeft(t);
            StringTrimRight(t);
            if(t == "")
                continue;
            if(out != "")
                out += "|";
            out += t;
        }
        return out;
    }

    //--- Round-trip a single row: serialize -> parse -> compare.
    static bool RoundTripRow(const TelemetryRow &original)
    {
        string line1 = SerializeRow(original);
        TelemetryRow parsed;
        if(!CCalibrationDataset::ParseRow(line1, parsed))
            return false;

        string line2 = SerializeRow(parsed);
        TelemetryRow reparsed;
        if(!CCalibrationDataset::ParseRow(line2, reparsed))
            return false;

        //--- Compare key fields (the ones most likely to break: quoted
        //    fields, floats, ints, strings).
        if(reparsed.schemaVersion != original.schemaVersion) return false;
        if(reparsed.confidence != original.confidence) return false;
        if(reparsed.componentData != original.componentData) return false;
        if(reparsed.firedRuleId != original.firedRuleId) return false;
        if(reparsed.ruleName != original.ruleName) return false;
        if(reparsed.ruleEvidenceIds != original.ruleEvidenceIds) return false;
        if(reparsed.layerTotal != original.layerTotal) return false;
        if(reparsed.hasBOS != original.hasBOS) return false;
        if(reparsed.hasLiquiditySweep != original.hasLiquiditySweep) return false;
        if(reparsed.signalTime != original.signalTime) return false;
        if(reparsed.symbol != original.symbol) return false;
        if(reparsed.direction != original.direction) return false;
        if(reparsed.outcome != original.outcome) return false;
        //--- Schema v5 gate columns.
        if(reparsed.swingQualifyingId != original.swingQualifyingId) return false;
        if(MathAbs(reparsed.swingAmplitude - original.swingAmplitude) > 1e-12) return false;
        if(reparsed.gateDecision != original.gateDecision) return false;
        return true;
    }

    void SortRulesByFrequency(void)
    {
        //--- Simple insertion sort (ruleCount is small, <= 16).
        for(int i = 1; i < m_ruleEntryCount; i++)
        {
            int keyId = m_ruleIds[i];
            string keyName = m_ruleNames[i];
            int keyTotal = m_ruleTotals[i];
            int keyComp = m_ruleComponents[i];
            int j = i - 1;
            while(j >= 0 && m_ruleTotals[j] < keyTotal)
            {
                m_ruleIds[j + 1] = m_ruleIds[j];
                m_ruleNames[j + 1] = m_ruleNames[j];
                m_ruleTotals[j + 1] = m_ruleTotals[j];
                m_ruleComponents[j + 1] = m_ruleComponents[j];
                j--;
            }
            m_ruleIds[j + 1] = keyId;
            m_ruleNames[j + 1] = keyName;
            m_ruleTotals[j + 1] = keyTotal;
            m_ruleComponents[j + 1] = keyComp;
        }
    }

public:
    CTelemetryHealthAnalyzer(void)
        : m_comboCount(0)
        , m_ruleEntryCount(0)
    {
        ArrayInitialize(m_ruleIds, 0);
        ArrayInitialize(m_ruleTotals, 0);
        ArrayInitialize(m_ruleComponents, 0);
    }

    //+------------------------------------------------------------------+
    //| Analyze a loaded dataset.  Single pass over all rows.            |
    //+------------------------------------------------------------------+
    TelemetryHealthReport Analyze(CCalibrationDataset &dataset, int roundTripSample = DEFAULT_ROUNDTRIP_SAMPLE)
    {
        TelemetryHealthReport report;
        m_comboCount = 0;
        m_ruleEntryCount = 0;

        int count = dataset.GetCount();
        report.parse.totalRows = count;
        report.parse.parsedRows = count; // dataset only holds parsed rows
        report.parse.schemaFailures = dataset.GetSkippedRows(); // rows the loader refused

        //--- If the dataset is empty, parsing is trivially successful
        //    but nothing else is applicable.
        if(count == 0)
        {
            report.parse.parseSuccessRate = 1.0;
            report.schema.schemaVersionPass = true;
            report.schema.legacyConsistencyPass = true;
            report.schema.roundTripPass = true;
            report.schema.coverageApplicable = false;
            report.healthScore = 100;
            report.verdict = HEALTH_PASS;
            report.verdictReason = "Empty dataset — all checks trivially pass (N/A).";
            return report;
        }

        report.parse.parseSuccessRate = (count > 0)
            ? (double)report.parse.parsedRows / (double)(report.parse.parsedRows + report.parse.schemaFailures)
            : 1.0;

        //--- Layer accumulators.
        long sumStructural = 0, sumLiquidity = 0, sumConfirmation = 0, sumTotal = 0;
        int minStructural = 999999, minLiquidity = 999999, minConfirmation = 999999, minTotal = 999999;
        int maxStructural = 0, maxLiquidity = 0, maxConfirmation = 0, maxTotal = 0;
        int componentRowsForLayers = 0;

        //--- Flag accumulators.
        int flagBOS = 0, flagCHOCH = 0, flagOB = 0, flagFVG = 0, flagPP = 0, flagSweep = 0;

        //--- Legacy consistency.
        int legacyInconsistent = 0;

        for(int i = 0; i < count; i++)
        {
            TelemetryRow row;
            if(!dataset.GetRow(i, row))
                continue;

            //--- Schema version distribution.
            if(row.schemaVersion >= 0 && row.schemaVersion < 10)
                report.schema.schemaVersionCounts[(int)row.schemaVersion]++;

            //--- Unexpected enum values.
            if(HasUnexpectedEnum(row))
                report.parse.unexpectedEnumCount++;

            //--- MISSING markers.
            report.schema.missingMarkerCount += CountMissingMarkers(row);

            //--- Legacy consistency.
            if(!LegacyRowConsistent(row))
                legacyInconsistent++;

            //--- Decided rows (v3+ rows only: component metrics are
            //    v3-pipeline concepts; legacy v2 rows are not scored).
            if(row.schemaVersion >= 3 &&
               (row.outcome == (int)TELEMETRY_OUTCOME_WIN ||
                row.outcome == (int)TELEMETRY_OUTCOME_LOSS ||
                row.outcome == (int)TELEMETRY_OUTCOME_BREAKEVEN))
                report.components.decidedRows++;

            //--- Component data.
            if(row.schemaVersion >= 3 && row.componentData == 1)
            {
                report.components.componentDataRows++;

                //--- Missing layers.  Rule-0 (no-signal) rows are exempt:
                //    the score is all-zero when no rule fires, so
                //    layerTotal == 0 is expected there.  Only rows where a
                //    rule FIRED but the layers were never stamped count.
                if(row.firedRuleId != 0 && row.layerTotal == 0)
                    report.components.missingLayerRows++;

                //--- Missing evidence (all flags UNKNOWN).
                if(row.hasBOS == (int)EV_UNKNOWN &&
                   row.hasCHOCH == (int)EV_UNKNOWN &&
                   row.hasOrderBlock == (int)EV_UNKNOWN &&
                   row.hasFVG == (int)EV_UNKNOWN &&
                   row.hasProtectedPoint == (int)EV_UNKNOWN &&
                   row.hasLiquiditySweep == (int)EV_UNKNOWN)
                    report.components.missingEvidenceRows++;

                //--- Flag coverage.
                if(row.hasBOS != (int)EV_UNKNOWN) flagBOS++;
                if(row.hasCHOCH != (int)EV_UNKNOWN) flagCHOCH++;
                if(row.hasOrderBlock != (int)EV_UNKNOWN) flagOB++;
                if(row.hasFVG != (int)EV_UNKNOWN) flagFVG++;
                if(row.hasProtectedPoint != (int)EV_UNKNOWN) flagPP++;
                if(row.hasLiquiditySweep != (int)EV_UNKNOWN) flagSweep++;

                //--- Layer distribution.
                componentRowsForLayers++;
                sumStructural += row.layerStructural;
                sumLiquidity += row.layerLiquidity;
                sumConfirmation += row.layerConfirmation;
                sumTotal += row.layerTotal;
                if(row.layerStructural < minStructural) minStructural = row.layerStructural;
                if(row.layerStructural > maxStructural) maxStructural = row.layerStructural;
                if(row.layerLiquidity < minLiquidity) minLiquidity = row.layerLiquidity;
                if(row.layerLiquidity > maxLiquidity) maxLiquidity = row.layerLiquidity;
                if(row.layerConfirmation < minConfirmation) minConfirmation = row.layerConfirmation;
                if(row.layerConfirmation > maxConfirmation) maxConfirmation = row.layerConfirmation;
                if(row.layerTotal < minTotal) minTotal = row.layerTotal;
                if(row.layerTotal > maxTotal) maxTotal = row.layerTotal;

                //--- Evidence combos.
                RegisterCombo(row.ruleEvidenceIds);
            }

            //--- Per-rule tracking (all rows, not just component rows).
            RegisterRule(row.firedRuleId, row.ruleName, row.componentData == 1);
        }

        //--- Schema version pass: 100% v3+ (v3, v3.1 and v5 rows count).
        int v3PlusCount = report.schema.schemaVersionCounts[3]
                        + report.schema.schemaVersionCounts[4]
                        + report.schema.schemaVersionCounts[5];
        report.schema.schemaVersionPass = (v3PlusCount == count);

        //--- Legacy consistency pass.
        report.schema.legacyConsistencyPass = (legacyInconsistent == 0);

        //--- Coverage applicability.
        report.schema.coverageApplicable = (report.components.componentDataRows > 0);

        //--- Component coverage.
        if(report.components.decidedRows > 0)
            report.components.componentCoverage =
                (double)report.components.componentDataRows / (double)report.components.decidedRows;

        //--- Flag coverage.
        if(report.components.componentDataRows > 0)
        {
            double denom = (double)report.components.componentDataRows;
            report.components.flagCoverageBOS = (double)flagBOS / denom;
            report.components.flagCoverageCHOCH = (double)flagCHOCH / denom;
            report.components.flagCoverageOrderBlock = (double)flagOB / denom;
            report.components.flagCoverageFVG = (double)flagFVG / denom;
            report.components.flagCoverageProtectedPoint = (double)flagPP / denom;
            report.components.flagCoverageLiquiditySweep = (double)flagSweep / denom;
        }

        //--- Layer distribution.
        if(componentRowsForLayers > 0)
        {
            report.layers.layerStructuralMin = minStructural;
            report.layers.layerStructuralMean = (double)sumStructural / (double)componentRowsForLayers;
            report.layers.layerStructuralMax = maxStructural;
            report.layers.layerLiquidityMin = minLiquidity;
            report.layers.layerLiquidityMean = (double)sumLiquidity / (double)componentRowsForLayers;
            report.layers.layerLiquidityMax = maxLiquidity;
            report.layers.layerConfirmationMin = minConfirmation;
            report.layers.layerConfirmationMean = (double)sumConfirmation / (double)componentRowsForLayers;
            report.layers.layerConfirmationMax = maxConfirmation;
            report.layers.layerTotalMin = minTotal;
            report.layers.layerTotalMean = (double)sumTotal / (double)componentRowsForLayers;
            report.layers.layerTotalMax = maxTotal;
        }

        //--- Rule coverage (sorted by frequency descending).
        SortRulesByFrequency();
        report.components.ruleCount = m_ruleEntryCount;
        for(int i = 0; i < m_ruleEntryCount && i < HEALTH_MAX_RULES; i++)
        {
            report.components.ruleCoverage[i].ruleId = m_ruleIds[i];
            report.components.ruleCoverage[i].ruleName = m_ruleNames[i];
            report.components.ruleCoverage[i].totalRows = m_ruleTotals[i];
            report.components.ruleCoverage[i].componentRows = m_ruleComponents[i];
            report.components.ruleCoverage[i].coveragePct =
                (m_ruleTotals[i] > 0) ? 100.0 * (double)m_ruleComponents[i] / (double)m_ruleTotals[i] : 0.0;
        }

        //--- Distinct evidence combos.
        report.components.distinctEvidenceCombos = m_comboCount;

        //--- Round-trip check.
        int sampleSize = MathMin(roundTripSample, count);
        report.schema.roundTripSampleSize = sampleSize;
        int rtFailures = 0;
        for(int i = 0; i < sampleSize; i++)
        {
            TelemetryRow row;
            if(!dataset.GetRow(i, row))
            {
                rtFailures++;
                continue;
            }
            //--- Round-trip audits the ACTIVE schema only: legacy v2/v3/v4
            //    rows are not re-serialized (SerializeRow always emits the
            //    active shape, which legacy rows must not be validated
            //    against).
            if(row.schemaVersion != (int)TELEMETRY_SCHEMA_VERSION)
                continue;
            if(!RoundTripRow(row))
                rtFailures++;
        }
        report.schema.roundTripFailures = rtFailures;
        report.schema.roundTripPass = (rtFailures == 0);

        //--- Compute health score.
        ComputeHealthScore(report);

        return report;
    }

private:
    void ComputeHealthScore(TelemetryHealthReport &report)
    {
        int score = 0;
        string reasons = "";

        //--- 1. Schema version (15 pts).
        if(report.schema.schemaVersionPass)
            score += HEALTH_WEIGHT_SCHEMA_VERSION;
        else
            reasons += "schemaVersion: not 100% v3+; ";

        //--- 2. Parse success (15 pts).
        if(report.parse.parseSuccessRate >= 0.9999 && report.parse.unexpectedEnumCount == 0)
            score += HEALTH_WEIGHT_PARSE_SUCCESS;
        else
        {
            if(report.parse.parseSuccessRate < 0.9999)
                reasons += StringFormat("parseSuccess: %.2f%%; ", report.parse.parseSuccessRate * 100.0);
            if(report.parse.unexpectedEnumCount > 0)
                reasons += StringFormat("unexpectedEnums: %d; ", report.parse.unexpectedEnumCount);
        }

        //--- 3. Component coverage (15 pts) — only if applicable.
        if(!report.schema.coverageApplicable)
        {
            //--- N/A: award full marks (no component rows to check).
            score += HEALTH_WEIGHT_COMPONENT_COVERAGE;
        }
        else if(report.components.componentCoverage > 0.99)
            score += HEALTH_WEIGHT_COMPONENT_COVERAGE;
        else
            reasons += StringFormat("componentCoverage: %.2f%%; ", report.components.componentCoverage * 100.0);

        //--- 4. Missing layers (10 pts).
        if(!report.schema.coverageApplicable)
            score += HEALTH_WEIGHT_MISSING_LAYERS;
        else if(report.components.missingLayerRows == 0)
            score += HEALTH_WEIGHT_MISSING_LAYERS;
        else
            reasons += StringFormat("missingLayers: %d; ", report.components.missingLayerRows);

        //--- 5. Missing evidence (10 pts).
        if(!report.schema.coverageApplicable)
            score += HEALTH_WEIGHT_MISSING_EVIDENCE;
        else if(report.components.missingEvidenceRows == 0)
            score += HEALTH_WEIGHT_MISSING_EVIDENCE;
        else
            reasons += StringFormat("missingEvidence: %d; ", report.components.missingEvidenceRows);

        //--- 6. MISSING markers (10 pts).
        if(report.schema.missingMarkerCount == 0)
            score += HEALTH_WEIGHT_MISSING_MARKERS;
        else
            reasons += StringFormat("missingMarkers: %d; ", report.schema.missingMarkerCount);

        //--- 7. Round-trip (15 pts).
        if(report.schema.roundTripPass)
            score += HEALTH_WEIGHT_ROUND_TRIP;
        else
            reasons += StringFormat("roundTrip: %d/%d failed; ",
                                    report.schema.roundTripFailures,
                                    report.schema.roundTripSampleSize);

        //--- 8. Legacy consistency (10 pts).
        if(report.schema.legacyConsistencyPass)
            score += HEALTH_WEIGHT_LEGACY_CONSIST;
        else
            reasons += "legacyConsistency: inconsistent; ";

        report.healthScore = score;

        //--- Verdict.
        if(score >= HEALTH_VERDICT_PASS_THRESHOLD)
        {
            report.verdict = HEALTH_PASS;
            report.verdictReason = (reasons == "") ? "All checks passed." : ("PASS with notes: " + reasons);
        }
        else if(score >= HEALTH_VERDICT_WARN_THRESHOLD)
        {
            report.verdict = HEALTH_WARN;
            report.verdictReason = "WARN: " + reasons;
        }
        else
        {
            report.verdict = HEALTH_FAIL;
            report.verdictReason = "FAIL: " + reasons;
        }
    }

public:
    //+------------------------------------------------------------------+
    //| Render verdict as string.                                        |
    //+------------------------------------------------------------------+
    static string VerdictString(ENUM_HEALTH_VERDICT v)
    {
        switch(v)
        {
            case HEALTH_PASS: return "PASS";
            case HEALTH_WARN: return "WARN";
            case HEALTH_FAIL: return "FAIL";
            case HEALTH_NA:   return "N/A";
        }
        return "UNKNOWN";
    }

    //+------------------------------------------------------------------+
    //| Render the full human-readable report card.                      |
    //+------------------------------------------------------------------+
    static string RenderCard(const TelemetryHealthReport &report)
    {
        string out = "";
        out += "========================== SCHEMA HEALTH GATE ==========================\n";
        out += "\n";
        out += StringFormat("  Verdict:       %s  (score %d/100)\n",
                            VerdictString(report.verdict), report.healthScore);
        out += StringFormat("  Report version: %d\n", HEALTH_REPORT_VERSION);
        out += StringFormat("  Schema version: %d\n", TELEMETRY_SCHEMA_VERSION);
        out += "\n";
        out += "--- Parse Health ---\n";
        out += StringFormat("  Total rows:          %d\n", report.parse.totalRows);
        out += StringFormat("  Parsed rows:         %d\n", report.parse.parsedRows);
        out += StringFormat("  Schema failures:     %d\n", report.parse.schemaFailures);
        out += StringFormat("  CSV failures:        %d\n", report.parse.csvFailures);
        out += StringFormat("  Unknown failures:    %d\n", report.parse.unknownFailures);
        out += StringFormat("  Unexpected enums:    %d\n", report.parse.unexpectedEnumCount);
        out += StringFormat("  Parse success rate:  %.2f%%\n", report.parse.parseSuccessRate * 100.0);
        out += "\n";
        out += "--- Schema Health ---\n";
        out += StringFormat("  Schema version pass:     %s\n", report.schema.schemaVersionPass ? "YES" : "NO");
        out += StringFormat("  v3 rows:                 %d\n", report.schema.schemaVersionCounts[3]);
        out += StringFormat("  v3.1 rows:               %d\n", report.schema.schemaVersionCounts[4]);
        out += StringFormat("  v5 (RL-HYP-01) rows:     %d\n", report.schema.schemaVersionCounts[5]);
        out += StringFormat("  v2 rows:                 %d\n", report.schema.schemaVersionCounts[2]);
        out += StringFormat("  Legacy consistency pass: %s\n", report.schema.legacyConsistencyPass ? "YES" : "NO");
        out += StringFormat("  Round-trip pass:         %s (%d/%d sampled)\n",
                            report.schema.roundTripPass ? "YES" : "NO",
                            report.schema.roundTripSampleSize - report.schema.roundTripFailures,
                            report.schema.roundTripSampleSize);
        out += StringFormat("  MISSING markers:         %d\n", report.schema.missingMarkerCount);
        out += StringFormat("  Coverage applicable:     %s\n", report.schema.coverageApplicable ? "YES" : "NO");
        out += "\n";
        out += "--- Component Health ---\n";
        out += StringFormat("  Component data rows:     %d\n", report.components.componentDataRows);
        out += StringFormat("  Decided rows:            %d\n", report.components.decidedRows);
        out += StringFormat("  Component coverage:      %.2f%%\n", report.components.componentCoverage * 100.0);
        out += StringFormat("  Missing layer rows:      %d\n", report.components.missingLayerRows);
        out += StringFormat("  Missing evidence rows:   %d\n", report.components.missingEvidenceRows);
        out += StringFormat("  Distinct evidence combos: %d\n", report.components.distinctEvidenceCombos);
        out += "\n";
        out += "  Per-flag coverage (fraction of component rows where flag != UNKNOWN):\n";
        out += StringFormat("    hasBOS:              %.2f%%\n", report.components.flagCoverageBOS * 100.0);
        out += StringFormat("    hasCHOCH:            %.2f%%\n", report.components.flagCoverageCHOCH * 100.0);
        out += StringFormat("    hasOrderBlock:       %.2f%%\n", report.components.flagCoverageOrderBlock * 100.0);
        out += StringFormat("    hasFVG:              %.2f%%\n", report.components.flagCoverageFVG * 100.0);
        out += StringFormat("    hasProtectedPoint:   %.2f%%\n", report.components.flagCoverageProtectedPoint * 100.0);
        out += StringFormat("    hasLiquiditySweep:   %.2f%%\n", report.components.flagCoverageLiquiditySweep * 100.0);
        out += "\n";
        out += "--- Layer Distribution (component rows only) ---\n";
        out += StringFormat("  Structural:   min=%d  mean=%.1f  max=%d\n",
                            report.layers.layerStructuralMin,
                            report.layers.layerStructuralMean,
                            report.layers.layerStructuralMax);
        out += StringFormat("  Liquidity:    min=%d  mean=%.1f  max=%d\n",
                            report.layers.layerLiquidityMin,
                            report.layers.layerLiquidityMean,
                            report.layers.layerLiquidityMax);
        out += StringFormat("  Confirmation: min=%d  mean=%.1f  max=%d\n",
                            report.layers.layerConfirmationMin,
                            report.layers.layerConfirmationMean,
                            report.layers.layerConfirmationMax);
        out += StringFormat("  Total:        min=%d  mean=%.1f  max=%d\n",
                            report.layers.layerTotalMin,
                            report.layers.layerTotalMean,
                            report.layers.layerTotalMax);
        out += "\n";
        out += "--- Rule Frequency (top 10) ---\n";
        int topRules = MathMin(10, report.components.ruleCount);
        for(int i = 0; i < topRules; i++)
        {
            RuleCoverageEntry r = report.components.ruleCoverage[i];
            double pct = (report.parse.parsedRows > 0)
                ? 100.0 * (double)r.totalRows / (double)report.parse.parsedRows
                : 0.0;
            out += StringFormat("  Rule %d (%s): %d rows (%.1f%%)  coverage %.1f%%\n",
                                r.ruleId, r.ruleName, r.totalRows, pct, r.coveragePct);
        }
        out += "\n";
        out += "--- Verdict Reason ---\n";
        out += "  " + report.verdictReason + "\n";
        out += "\n";
        out += "========================== END HEALTH GATE ============================\n";
        return out;
    }

    //+------------------------------------------------------------------+
    //| Render the detailed CSV (all rules, all flags).                  |
    //+------------------------------------------------------------------+
    static string RenderCsv(const TelemetryHealthReport &report)
    {
        string out = "";
        out += "section,key,value\n";
        out += StringFormat("parse,totalRows,%d\n", report.parse.totalRows);
        out += StringFormat("parse,parsedRows,%d\n", report.parse.parsedRows);
        out += StringFormat("parse,schemaFailures,%d\n", report.parse.schemaFailures);
        out += StringFormat("parse,csvFailures,%d\n", report.parse.csvFailures);
        out += StringFormat("parse,unknownFailures,%d\n", report.parse.unknownFailures);
        out += StringFormat("parse,unexpectedEnumCount,%d\n", report.parse.unexpectedEnumCount);
        out += StringFormat("parse,parseSuccessRate,%.6f\n", report.parse.parseSuccessRate);
        out += StringFormat("schema,schemaVersionPass,%d\n", report.schema.schemaVersionPass ? 1 : 0);
        out += StringFormat("schema,v3Rows,%d\n", report.schema.schemaVersionCounts[3]);
        out += StringFormat("schema,v31Rows,%d\n", report.schema.schemaVersionCounts[4]);
        out += StringFormat("schema,v5Rows,%d\n", report.schema.schemaVersionCounts[5]);
        out += StringFormat("schema,v2Rows,%d\n", report.schema.schemaVersionCounts[2]);
        out += StringFormat("schema,legacyConsistencyPass,%d\n", report.schema.legacyConsistencyPass ? 1 : 0);
        out += StringFormat("schema,roundTripPass,%d\n", report.schema.roundTripPass ? 1 : 0);
        out += StringFormat("schema,roundTripSampleSize,%d\n", report.schema.roundTripSampleSize);
        out += StringFormat("schema,roundTripFailures,%d\n", report.schema.roundTripFailures);
        out += StringFormat("schema,missingMarkerCount,%d\n", report.schema.missingMarkerCount);
        out += StringFormat("schema,coverageApplicable,%d\n", report.schema.coverageApplicable ? 1 : 0);
        out += StringFormat("component,componentDataRows,%d\n", report.components.componentDataRows);
        out += StringFormat("component,decidedRows,%d\n", report.components.decidedRows);
        out += StringFormat("component,componentCoverage,%.6f\n", report.components.componentCoverage);
        out += StringFormat("component,missingLayerRows,%d\n", report.components.missingLayerRows);
        out += StringFormat("component,missingEvidenceRows,%d\n", report.components.missingEvidenceRows);
        out += StringFormat("component,distinctEvidenceCombos,%d\n", report.components.distinctEvidenceCombos);
        out += StringFormat("component,flagCoverageBOS,%.6f\n", report.components.flagCoverageBOS);
        out += StringFormat("component,flagCoverageCHOCH,%.6f\n", report.components.flagCoverageCHOCH);
        out += StringFormat("component,flagCoverageOrderBlock,%.6f\n", report.components.flagCoverageOrderBlock);
        out += StringFormat("component,flagCoverageFVG,%.6f\n", report.components.flagCoverageFVG);
        out += StringFormat("component,flagCoverageProtectedPoint,%.6f\n", report.components.flagCoverageProtectedPoint);
        out += StringFormat("component,flagCoverageLiquiditySweep,%.6f\n", report.components.flagCoverageLiquiditySweep);
        out += StringFormat("layer,structuralMin,%d\n", report.layers.layerStructuralMin);
        out += StringFormat("layer,structuralMean,%.4f\n", report.layers.layerStructuralMean);
        out += StringFormat("layer,structuralMax,%d\n", report.layers.layerStructuralMax);
        out += StringFormat("layer,liquidityMin,%d\n", report.layers.layerLiquidityMin);
        out += StringFormat("layer,liquidityMean,%.4f\n", report.layers.layerLiquidityMean);
        out += StringFormat("layer,liquidityMax,%d\n", report.layers.layerLiquidityMax);
        out += StringFormat("layer,confirmationMin,%d\n", report.layers.layerConfirmationMin);
        out += StringFormat("layer,confirmationMean,%.4f\n", report.layers.layerConfirmationMean);
        out += StringFormat("layer,confirmationMax,%d\n", report.layers.layerConfirmationMax);
        out += StringFormat("layer,totalMin,%d\n", report.layers.layerTotalMin);
        out += StringFormat("layer,totalMean,%.4f\n", report.layers.layerTotalMean);
        out += StringFormat("layer,totalMax,%d\n", report.layers.layerTotalMax);
        out += StringFormat("score,healthScore,%d\n", report.healthScore);
        out += StringFormat("score,verdict,%s\n", VerdictString(report.verdict));

        //--- Per-rule rows.
        for(int i = 0; i < report.components.ruleCount; i++)
        {
            RuleCoverageEntry r = report.components.ruleCoverage[i];
            out += StringFormat("rule,%d,%s,%d,%d,%.4f\n",
                                r.ruleId, r.ruleName, r.totalRows, r.componentRows, r.coveragePct);
        }
        return out;
    }

    //+------------------------------------------------------------------+
    //| Render the minimal JSON (CI-oriented).                           |
    //+------------------------------------------------------------------+
    static string RenderJson(const TelemetryHealthReport &report)
    {
        return StringFormat(
            "{\n"
            "  \"healthReportVersion\": %d,\n"
            "  \"schemaVersion\": %d,\n"
            "  \"rows\": %d,\n"
            "  \"parsedRows\": %d,\n"
            "  \"coverage\": %.4f,\n"
            "  \"score\": %d,\n"
            "  \"verdict\": \"%s\"\n"
            "}",
            HEALTH_REPORT_VERSION,
            TELEMETRY_SCHEMA_VERSION,
            report.parse.totalRows,
            report.parse.parsedRows,
            report.components.componentCoverage,
            report.healthScore,
            VerdictString(report.verdict));
    }
};

#endif