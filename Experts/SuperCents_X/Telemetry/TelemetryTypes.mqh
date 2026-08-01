//+------------------------------------------------------------------+
//|                                          TelemetryTypes.mqh        |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  @frozen v2.9  TelemetryRow  (schemaVersion = 1)
//  @frozen v2.9.2 TelemetryRow  (schemaVersion = 2)
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
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_TYPES_MQH__
#define __TELEMETRY_TYPES_MQH__

#include "../Utils/Constants.mqh"
#include "../Confluence/ConfluenceTypes.mqh"
#include "../Entry/EntryTypes.mqh"

//--- Canonical EA version used by the configuration fingerprint.
#define TELEMETRY_EA_VERSION "v3.0"

#define TELEMETRY_SCHEMA_VERSION     2
#define MAX_TELEMETRY_VALIDATORS     12
#define TELEMETRY_COMPONENT_COUNT    6

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

