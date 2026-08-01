//+------------------------------------------------------------------+
//|                                          TelemetryTypes.mqh        |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  @frozen v2.9  TelemetryRow  (schemaVersion = 1)
//  @frozen v2.9.2 TelemetryRow  (schemaVersion = 2)
//  @frozen v3.1   TelemetryRow  (schemaVersion = 3)
//
//  CONTRACT RULES (append-only, never break):
//  - Column order and semantics are frozen once data collection starts.
//  - Never rename or reorder existing fields/columns.
//  - Reserved fields (actualOutcome, actualOutcomeSource) remain empty
//    until used; they must never be repurposed.
//  - New fields require a schemaVersion bump and an append-only CSV
//    migration (new columns at the END of the header).
//
//  v2 semantics (v2.9.2): all confidence columns (confidence,
//  legacyConfidence, newConfidence, confThreshold) are normalized to the
//  0-1 scale. In v1, legacyConfidence was stored on the 0-100 scale;
//  v2 rows are the only rows the collector produces. Column layout is
//  identical to v1 (append-only preserved).
//
//  v3 semantics (Sprint 17 Evidence Capture): the runtime scores with
//  the rule-layer architecture (rule + layer + evidence flags), which
//  the v1/v2 columns never captured (16.1B: all component raws zero in
//  v3.0 rows). v3 appends 23 observation columns: schema metadata,
//  rule-level evidence (fired rule id/name, pre-weight score and
//  confidence, evidence ids), layer decomposition (structural/
//  liquidity/confirmation/total raws), tristate evidence flags and the
//  signal creation time.  All v2 columns keep their exact positions and
//  semantics; v3 is strictly append-only over v2.  Structural
//  diagnostics refuse schemaVersion < 3 (see CalibrationStructural).
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_TYPES_MQH__
#define __TELEMETRY_TYPES_MQH__

#include "../Utils/Constants.mqh"
#include "../Confluence/ConfluenceTypes.mqh"
#include "../Entry/EntryTypes.mqh"

//--- Canonical EA version used by the configuration fingerprint.
#define TELEMETRY_EA_VERSION "v3.0"

#define TELEMETRY_SCHEMA_VERSION     3
#define MAX_TELEMETRY_VALIDATORS     12
#define TELEMETRY_COMPONENT_COUNT    6

//--- Schema v3 identity (Sprint 17 Evidence Capture). The schema
//    fingerprint TelemetrySchemaId = "v3.0" combines schemaVersion and
//    evidenceContract; downstream tooling refuses on mismatch without
//    relying on file naming.
#define TELEMETRY_SCORE_ARCHITECTURE   "rule-layer-v1"   // versioned scoring architecture (rule-layer-v2 will exist someday)
#define TELEMETRY_TELEMETRY_ARCHITECTURE "rule-layer"    // decomposition model of componentData
#define TELEMETRY_EVIDENCE_CONTRACT    "2026-08"         // contract revision; bump on any semantic change
#define TELEMETRY_CONFIDENCE_MODEL     "raw"             // transform state of the score

//--- Tristate evidence semantics (refinement B): a flag the runtime did
//    not evaluate must not be recorded as FALSE.
enum ENUM_EVIDENCE_STATE
{
    EV_UNKNOWN = 0,
    EV_FALSE,
    EV_TRUE
};

//--- CSV column order — part of the frozen v1 contract. Append-only.
#define TELEMETRY_CSV_HEADER_V1 \
    "schemaVersion,configFingerprint,timestamp,symbol,timeframe,eaVersion," \
    "decisionId,direction,confidence," \
    "structureRaw,structureWeight,structureContribution," \
    "obRaw,obWeight,obContribution," \
    "fvgRaw,fvgWeight,fvgContribution," \
    "trendRaw,trendWeight,trendContribution," \
    "liquidityRaw,liquidityWeight,liquidityContribution," \
    "pdRaw,pdWeight,pdContribution," \
    "validatorResults,confThreshold,newDecision,legacyDecision," \
    "decisionMatch,directionMatch,legacyConfidence,newConfidence,disabledValidators," \
    "outcomeSource,outcome,rMultiple,barsHeld,exitReason,entryPrice,exitPrice," \
    "actualOutcome,actualOutcomeSource"

//--- Active v2 header (v2.9.2): identical 45 columns; all confidence
//    columns (confidence, confThreshold, legacyConfidence, newConfidence)
//    are normalized to 0-1.
#define TELEMETRY_CSV_HEADER_V2 \
    "schemaVersion,configFingerprint,timestamp,symbol,timeframe,eaVersion," \
    "decisionId,direction,confidence," \
    "structureRaw,structureWeight,structureContribution," \
    "obRaw,obWeight,obContribution," \
    "fvgRaw,fvgWeight,fvgContribution," \
    "trendRaw,trendWeight,trendContribution," \
    "liquidityRaw,liquidityWeight,liquidityContribution," \
    "pdRaw,pdWeight,pdContribution," \
    "validatorResults,confThreshold,newDecision,legacyDecision," \
    "decisionMatch,directionMatch,legacyConfidence,newConfidence,disabledValidators," \
    "outcomeSource,outcome,rMultiple,barsHeld,exitReason,entryPrice,exitPrice," \
    "actualOutcome,actualOutcomeSource"

//--- Active v3 header (Sprint 17): 68 columns = v2 (45) + 23 evidence
//    columns appended at the END. Frozen once collection starts.
#define TELEMETRY_CSV_HEADER_V3 \
    TELEMETRY_CSV_HEADER_V2 "," \
    "scoreArchitecture,telemetryArchitecture,evidenceContract,confidenceModel,componentData," \
    "firedRuleId,ruleName,ruleScore,ruleConfidence,ruleEvidenceCount,ruleEvidenceIds,trendAligned," \
    "layerStructural,layerLiquidity,layerConfirmation,layerTotal," \
    "hasBOS,hasCHOCH,hasOrderBlock,hasFVG,hasProtectedPoint,hasLiquiditySweep," \
    "signalTime"

enum ENUM_TELEMETRY_OUTCOME
{
    TELEMETRY_OUTCOME_UNKNOWN = 0,
    TELEMETRY_OUTCOME_WIN,
    TELEMETRY_OUTCOME_LOSS,
    TELEMETRY_OUTCOME_BREAKEVEN
};

enum ENUM_OUTCOME_SOURCE
{
    OUTCOME_SOURCE_NONE = 0,
    OUTCOME_SOURCE_SIMULATED,
    OUTCOME_SOURCE_ACTUAL
};

enum ENUM_EXIT_REASON
{
    EXIT_REASON_NONE = 0,
    EXIT_REASON_TP,
    EXIT_REASON_SL,
    EXIT_REASON_BREAKEVEN,
    EXIT_REASON_HORIZON
};

enum ENUM_CALIB_EXIT_POLICY
{
    CALIB_POLICY_FIXED_RR = 0,
    CALIB_POLICY_ENTRY_RESOLVER,
    CALIB_POLICY_ATR,
    CALIB_POLICY_TRAILING
};

//--- Per-validator result recorded inside a telemetry row.
struct TelemetryValidatorResult
{
    string name;
    int    result;   // ENUM_FILTER_RESULT: 0=PASS, 1=WARNING, 2=FAIL

    TelemetryValidatorResult(void)
        : name("")
        , result(FILTER_PASS)
    {}
};

//--- Simulated forward outcome produced by the outcome simulator.
struct SimulatedOutcome
{
    ENUM_TELEMETRY_OUTCOME outcome;
    double              rMultiple;
    int                 barsHeld;
    ENUM_EXIT_REASON    exitReason;
    double              entryPrice;
    double              exitPrice;

    SimulatedOutcome(void)
        : outcome(TELEMETRY_OUTCOME_UNKNOWN)
        , rMultiple(0.0)
        , barsHeld(0)
        , exitReason(EXIT_REASON_NONE)
        , entryPrice(0.0)
        , exitPrice(0.0)
    {}
};

// @frozen v2.9
// @frozen v2.9.2 (schemaVersion = 2: confidence columns normalized 0-1)
//--- One decision = one telemetry row.  Frozen contract (see header).
//    Schema freeze: rows must stay CSV-compatible with telemetry_v2_*.
//    Any schema change requires a new schemaVersion + reader migration.
struct TelemetryRow
{
    uint     schemaVersion;
    ulong   configFingerprint;
    datetime timestamp;
    string   symbol;
    int      timeframe;          // ENUM_TIMEFRAMES
    string   eaVersion;
    int      decisionId;         // run-local monotonic id
    int      direction;          // ConfluenceDirection
    double   confidence;         // 0-1 (new-engine decision confidence, v2)

    //--- Component raw scores, weights and contributions (all three stored).
    double structureRaw, structureWeight, structureContribution;
    double obRaw,        obWeight,        obContribution;
    double fvgRaw,       fvgWeight,       fvgContribution;
    double trendRaw,     trendWeight,     trendContribution;
    double liquidityRaw, liquidityWeight, liquidityContribution;
    double pdRaw,        pdWeight,        pdContribution;

    //--- Per-validator outcomes (packed as "Name=0|Name=2|..." in CSV).
    TelemetryValidatorResult validators[MAX_TELEMETRY_VALIDATORS];
    int      validatorCount;

    //--- Confidence threshold that was active for this row (enables exact replay). 0-1.
    double   confThreshold;

    //--- Decisions.
    bool     newDecision;
    bool     legacyDecision;
    bool     decisionMatch;    // new vs legacy qualification agreement
    bool     directionMatch;   // legacy decision direction vs new decision direction
    double   legacyConfidence; // 0-1 (v2; was 0-100 in v1)
    double   newConfidence;    // 0-1
    string   disabledValidators;   // comma-separated, sorted

    //--- Simulated outcome (settled for every row with a direction).
    int      outcomeSource;        // ENUM_OUTCOME_SOURCE
    int      outcome;              // ENUM_TELEMETRY_OUTCOME
    double   rMultiple;
    int      barsHeld;
    int      exitReason;           // ENUM_EXIT_REASON
    double   entryPrice;
    double   exitPrice;

    //--- RESERVED (must remain empty until used; never repurpose).
    int      actualOutcome;        // reserved
    int      actualOutcomeSource;  // reserved

    //--- Schema v3 evidence columns (Sprint 17; append-only over v2).
    //    Metadata (schema identity; refusal checks key off these).
    string   scoreArchitecture;
    string   telemetryArchitecture;
    string   evidenceContract;
    string   confidenceModel;
    int      componentData;        // 1 = row carries rule/layer/evidence observations

    //--- Rule-level evidence (pre-weighting observations).
    int      firedRuleId;          // RuleType enum value (frozen)
    string   ruleName;             // human-readable name (may evolve)
    int      ruleScore;            // 0-100, before any weighting
    double   ruleConfidence;       // 0-1, before weighting
    int      ruleEvidenceCount;
    string   ruleEvidenceIds;      // packed "id1,id2,..."
    int      trendAligned;         // ENUM_EVIDENCE_STATE

    //--- Layer decomposition (the v3.0 components, pre-normalization).
    //    Prefix "layer" keeps these distinct from the legacy 6-component
    //    columns (structureRaw/liquidityRaw/...).
    int      layerStructural;      // 0-50
    int      layerLiquidity;       // 0-30
    int      layerConfirmation;    // 0-20
    int      layerTotal;           // 0-100 (= 100 * confidence)

    //--- Evidence flags (tristate: ENUM_EVIDENCE_STATE).
    int      hasBOS;
    int      hasCHOCH;
    int      hasOrderBlock;
    int      hasFVG;
    int      hasProtectedPoint;
    int      hasLiquiditySweep;

    datetime signalTime;           // signal creation time (decision capture time stays in `timestamp`)

    TelemetryRow(void)
        : schemaVersion(TELEMETRY_SCHEMA_VERSION)
        , configFingerprint(0)
        , timestamp(0)
        , symbol("")
        , timeframe((int)PERIOD_CURRENT)
        , eaVersion(TELEMETRY_EA_VERSION)
        , decisionId(0)
        , direction((int)CONFLUENCE_NONE)
        , confidence(0.0)
        , structureRaw(0.0), structureWeight(0.0), structureContribution(0.0)
        , obRaw(0.0),        obWeight(0.0),        obContribution(0.0)
        , fvgRaw(0.0),       fvgWeight(0.0),       fvgContribution(0.0)
        , trendRaw(0.0),     trendWeight(0.0),     trendContribution(0.0)
        , liquidityRaw(0.0), liquidityWeight(0.0), liquidityContribution(0.0)
        , pdRaw(0.0),        pdWeight(0.0),        pdContribution(0.0)
        , validatorCount(0)
        , confThreshold(0.60)
        , newDecision(false)
        , legacyDecision(false)
        , decisionMatch(false)
        , directionMatch(false)
        , legacyConfidence(0.0)
        , newConfidence(0.0)
        , disabledValidators("")
        , outcomeSource((int)OUTCOME_SOURCE_NONE)
        , outcome((int)TELEMETRY_OUTCOME_UNKNOWN)
        , rMultiple(0.0)
        , barsHeld(0)
        , exitReason((int)EXIT_REASON_NONE)
        , entryPrice(0.0)
        , exitPrice(0.0)
        , actualOutcome((int)TELEMETRY_OUTCOME_UNKNOWN)
        , actualOutcomeSource((int)OUTCOME_SOURCE_NONE)
        , scoreArchitecture(TELEMETRY_SCORE_ARCHITECTURE)
        , telemetryArchitecture(TELEMETRY_TELEMETRY_ARCHITECTURE)
        , evidenceContract(TELEMETRY_EVIDENCE_CONTRACT)
        , confidenceModel(TELEMETRY_CONFIDENCE_MODEL)
        , componentData(0)
        , firedRuleId(0)
        , ruleName("")
        , ruleScore(0)
        , ruleConfidence(0.0)
        , ruleEvidenceCount(0)
        , ruleEvidenceIds("")
        , trendAligned((int)EV_UNKNOWN)
        , layerStructural(0)
        , layerLiquidity(0)
        , layerConfirmation(0)
        , layerTotal(0)
        , hasBOS((int)EV_UNKNOWN)
        , hasCHOCH((int)EV_UNKNOWN)
        , hasOrderBlock((int)EV_UNKNOWN)
        , hasFVG((int)EV_UNKNOWN)
        , hasProtectedPoint((int)EV_UNKNOWN)
        , hasLiquiditySweep((int)EV_UNKNOWN)
        , signalTime(0)
    {}

    void SetComponent(ENUM_CONFLUENCE_COMPONENT type, double raw, double weight, double contribution)
    {
        switch(type)
        {
            case COMPONENT_STRUCTURE:        structureRaw = raw;        structureWeight = weight;        structureContribution = contribution; break;
            case COMPONENT_ORDER_BLOCK:      obRaw = raw;               obWeight = weight;               obContribution = contribution;          break;
            case COMPONENT_FVG:              fvgRaw = raw;              fvgWeight = weight;              fvgContribution = contribution;         break;
            case COMPONENT_TREND:            trendRaw = raw;            trendWeight = weight;            trendContribution = contribution;       break;
            case COMPONENT_LIQUIDITY:        liquidityRaw = raw;        liquidityWeight = weight;        liquidityContribution = contribution;   break;
            case COMPONENT_PREMIUM_DISCOUNT: pdRaw = raw;               pdWeight = weight;               pdContribution = contribution;          break;
        }
    }

    double GetRaw(ENUM_CONFLUENCE_COMPONENT type) const
    {
        switch(type)
        {
            case COMPONENT_STRUCTURE:        return structureRaw;
            case COMPONENT_ORDER_BLOCK:      return obRaw;
            case COMPONENT_FVG:              return fvgRaw;
            case COMPONENT_TREND:            return trendRaw;
            case COMPONENT_LIQUIDITY:        return liquidityRaw;
            case COMPONENT_PREMIUM_DISCOUNT: return pdRaw;
        }
        return 0.0;
    }

    //--- Recompute weighted confidence from stored raw scores (offline replay).
    double ReplayConfidence(const double &weights[]) const
    {
        double total = 0.0;
        total += structureRaw * weights[0] / 100.0;
        total += obRaw        * weights[1] / 100.0;
        total += fvgRaw       * weights[2] / 100.0;
        total += liquidityRaw * weights[3] / 100.0;
        total += trendRaw     * weights[4] / 100.0;
        total += pdRaw        * weights[5] / 100.0;
        if(total < 0.0) total = 0.0;
        if(total > 100.0) total = 100.0;
        return total;
    }

    //--- Pack validator results into a stable "Name=0|Name=2" string.
    string PackValidatorResults(void) const
    {
        string out = "";
        for(int i = 0; i < validatorCount; i++)
        {
            if(out != "") out += "|";
            out += validators[i].name + "=" + IntegerToString(validators[i].result);
        }
        return out;
    }

    bool UnpackValidatorResults(const string packed)
    {
        validatorCount = 0;
        string parts[];
        int n = StringSplit(packed, '|', parts);
        for(int i = 0; i < n && validatorCount < MAX_TELEMETRY_VALIDATORS; i++)
        {
            int eq = StringFind(parts[i], "=");
            if(eq <= 0)
                continue;
            validators[validatorCount].name = StringSubstr(parts[i], 0, eq);
            validators[validatorCount].result = (int)StringToInteger(StringSubstr(parts[i], eq + 1));
            validatorCount++;
        }
        return true;
    }

    bool HasValidatorResult(const string name) const
    {
        for(int i = 0; i < validatorCount; i++)
        {
            if(validators[i].name == name)
                return true;
        }
        return false;
    }

    int GetValidatorResult(const string name) const
    {
        for(int i = 0; i < validatorCount; i++)
        {
            if(validators[i].name == name)
                return validators[i].result;
        }
        return -1;
    }

    //--- Replay the full new-engine decision for a given confidence threshold.
    //    The confluence gate is re-evaluated; all other validators use stored
    //    results (a missing result is treated as PASS â€” with collectAll
    //    telemetry every enabled validator is recorded, so missing means
    //    the validator was disabled for this configuration).
    bool ReplayDecision(double threshold) const
    {
        if(confidence < threshold)
            return false;
        for(int i = 0; i < validatorCount; i++)
        {
            if(validators[i].name == "ConfluenceValidator")
                continue;
            if(validators[i].result == FILTER_FAIL)
                return false;
        }
        return true;
    }
};

//--- Frozen rule-ID -> name mapping (refinement C: ids are stable,
//    names may evolve). Mirrors the RuleType enum order.
string TelemetryRuleName(const int ruleId)
{
    switch(ruleId)
    {
        case 1:  return "BOS_OB_BULLISH";
        case 2:  return "BOS_OB_BEARISH";
        case 3:  return "OB_FVG_BULLISH";
        case 4:  return "OB_FVG_BEARISH";
        case 5:  return "LIQUIDITY_BOS_BULLISH";
        case 6:  return "LIQUIDITY_BOS_BEARISH";
        case 7:  return "CHOCH_OB_REVERSAL";
    }
    return "";
}

//--- Map a runtime boolean observation to the tristate contract.
int TelemetryEvidenceState(const bool evaluated)
{
    return evaluated ? (int)EV_TRUE : (int)EV_FALSE;
}

//--- Runtime calibration configuration (EA inputs -> engines).
struct CalibrationConfig
{
    bool     telemetryEnabled;
    double   minConfidence;
    double   weights[TELEMETRY_COMPONENT_COUNT]; // S, OB, FVG, Liq, Trend, PD
    string   disabledValidators;                  // comma-separated (unsorted input)
    int      exitPolicy;                          // ENUM_CALIB_EXIT_POLICY
    double   slR;
    double   tpR;
    int      maxHoldBars;
    bool     useProductionProviders;
    string   eaVersion;
    string   spreadMode;                          // "quote" | "tick" | "fixed"
    int      brokerDigits;

    CalibrationConfig(void)
        : telemetryEnabled(true)
        , minConfidence(0.60)
        , exitPolicy((int)CALIB_POLICY_FIXED_RR)
        , slR(1.0)
        , tpR(2.0)
        , maxHoldBars(50)
        , useProductionProviders(false)
        , eaVersion(TELEMETRY_EA_VERSION)
        , spreadMode("quote")
        , brokerDigits(5)
    {
        weights[0] = 25.0;
        weights[1] = 20.0;
        weights[2] = 15.0;
        weights[3] = 15.0;
        weights[4] = 15.0;
        weights[5] = 10.0;
    }
};

#endif

