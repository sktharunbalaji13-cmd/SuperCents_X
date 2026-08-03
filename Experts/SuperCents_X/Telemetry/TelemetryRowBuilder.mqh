//+------------------------------------------------------------------+
//|                                        TelemetryRowBuilder.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             v2.9.2 (Sprint 14.6)  |
//+------------------------------------------------------------------+
//  Builds a TelemetryRow (schema v2) from the per-bar decision state:
//
//    ConfluenceResult  -> direction, component raw/weight/contribution
//    new Decision      -> confidence (0-1), qualified flag, validator results
//    legacy Decision   -> confidence (0-1), qualified flag (decision-level
//                         comparison — A-01 fix; no plan-existence proxy)
//
//  All confidence columns are normalized 0-1 (A-02 fix).
//  Static and dependency-light so the unit test suite can exercise it
//  without instantiating the EA.
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_ROW_BUILDER_MQH__
#define __TELEMETRY_ROW_BUILDER_MQH__

#include "TelemetryTypes.mqh"
#include "ConfigFingerprint.mqh"
#include "../Confluence/ConfluenceTypes.mqh"
#include "../Confluence/ConfluenceWeights.mqh"
#include "../Entry/EntryDecisionTypes.mqh"

class CTelemetryRowBuilder
{
private:
    static ulong ComputeFingerprint(const double confThreshold,
                                    const ConfluenceWeights &weights,
                                    const string symbol,
                                    const int timeframe,
                                    const string disabledValidators,
                                    const string spreadMode,
                                    const int brokerDigits)
    {
        CalibrationConfig cfg;
        cfg.minConfidence = confThreshold;
        cfg.weights[0] = weights.structure;
        cfg.weights[1] = weights.orderBlock;
        cfg.weights[2] = weights.fvg;
        cfg.weights[3] = weights.liquidity;
        cfg.weights[4] = weights.trend;
        cfg.weights[5] = weights.premiumDiscount;
        cfg.disabledValidators = disabledValidators;
        cfg.spreadMode = spreadMode;
        cfg.brokerDigits = brokerDigits;
        cfg.telemetryEnabled = true;
        cfg.useProductionProviders = false;
        return CConfigFingerprint::Compute(cfg, symbol, timeframe, "FixedRR", "1");
    }

public:
    static bool Build(TelemetryRow &out,
                      const ConfluenceResult &cr,
                      const EntryDecision &newDecision,
                      const bool hasLegacy,
                      const EntryDecision &legacyDecision,
                      const double confThreshold,
                      const ConfluenceWeights &weights,
                      const string symbol,
                      const int timeframe,
                      const string disabledValidators,
                      const string spreadMode,
                      const int brokerDigits)
    {
        out = TelemetryRow();
        out.configFingerprint = ComputeFingerprint(confThreshold, weights, symbol,
                                                   timeframe, disabledValidators,
                                                   spreadMode, brokerDigits);
        out.timestamp = TimeCurrent();
        out.symbol = symbol;
        out.timeframe = timeframe;
        out.direction = (int)cr.direction;
        out.confidence = newDecision.confidence;

        for(int i = 0; i < cr.componentCount; i++)
        {
            out.SetComponent(cr.components[i].type,
                             cr.components[i].score,
                             cr.components[i].weight,
                             cr.components[i].contribution);
        }

        out.validatorCount = 0;
        for(int i = 0; i < newDecision.filterCount && out.validatorCount < MAX_TELEMETRY_VALIDATORS; i++)
        {
            if(newDecision.filters[i].validatorName == "")
                continue;
            out.validators[out.validatorCount].name = newDecision.filters[i].validatorName;
            out.validators[out.validatorCount].result = (int)newDecision.filters[i].result;
            out.validatorCount++;
        }

        out.confThreshold = confThreshold;
        out.newDecision = (newDecision.status == DECISION_QUALIFIED);
        out.legacyDecision = hasLegacy && (legacyDecision.status == DECISION_QUALIFIED);
        out.decisionMatch = (out.newDecision == out.legacyDecision);
        out.directionMatch = hasLegacy && (legacyDecision.direction == newDecision.direction);
        out.legacyConfidence = hasLegacy ? legacyDecision.confidence : 0.0;
        out.newConfidence = newDecision.confidence;
        out.disabledValidators = CConfigFingerprint::SortDisabledValidators(disabledValidators);

        //--- Outcome fields stay at their UNKNOWN / NONE defaults here.
        //    Sprint 15.3: the symbol context settles each row after
        //    TELEMETRY_SETTLE_MAX_HOLD_BARS bars via CForwardOutcomeSimulator
        //    (FixedRR policy, matching the frozen "FixedRR"/"1" config tag)
        //    and fills outcome/outcomeSource/rMultiple/barsHeld/exitReason
        //    before the row reaches the collector.
        return true;
    }

    //--- Schema v3 (Sprint 17 Evidence Capture): builds a v2-compatible
    //    row and appends the rule/layer/evidence observations captured
    //    from the runtime ConfluenceSignal. Observation-only: the layer
    //    decomposition, active counts and contributions are stored as
    //    raw values; derived metrics are never persisted.
    static bool BuildWithEvidence(TelemetryRow &out,
                                  const ConfluenceResult &cr,
                                  const EntryDecision &newDecision,
                                  const bool hasLegacy,
                                  const EntryDecision &legacyDecision,
                                  const double confThreshold,
                                  const ConfluenceWeights &weights,
                                  const string symbol,
                                  const int timeframe,
                                  const string disabledValidators,
                                  const string spreadMode,
                                  const int brokerDigits,
                                  const ConfluenceSignal &signal)
    {
        if(!Build(out, cr, newDecision, hasLegacy, legacyDecision, confThreshold,
                  weights, symbol, timeframe, disabledValidators,
                  spreadMode, brokerDigits))
            return false;

        //--- Metadata (schema identity; refusal checks key off these).
        out.scoreArchitecture = TELEMETRY_SCORE_ARCHITECTURE;
        out.telemetryArchitecture = TELEMETRY_TELEMETRY_ARCHITECTURE;
        out.evidenceContract = TELEMETRY_EVIDENCE_CONTRACT;
        out.confidenceModel = TELEMETRY_CONFIDENCE_MODEL;
        out.componentData = 1;

        //--- Rule-level evidence (pre-weighting observations).
        out.firedRuleId = (int)signal.currentRule.type;
        out.ruleName = TelemetryRuleName(out.firedRuleId);
        out.ruleScore = signal.currentRule.score;
        out.ruleConfidence = signal.currentRule.confidence;
        out.ruleEvidenceCount = signal.currentRule.evidenceCount;
        out.ruleEvidenceIds = PackEvidenceIds(signal.currentRule.evidenceIds,
                                              signal.currentRule.evidenceCount);
        out.trendAligned = TelemetryEvidenceState(signal.trendAligned);

        //--- Layer decomposition (the v3.0 components, pre-normalization).
        out.layerStructural = signal.score.structural;
        out.layerLiquidity = signal.score.liquidity;
        out.layerConfirmation = signal.score.confirmation;
        out.layerTotal = signal.score.total;

        //--- Evidence flags (tristate: never assume false for unevaluated).
        out.hasBOS = TelemetryEvidenceState(signal.hasBOS);
        out.hasCHOCH = TelemetryEvidenceState(signal.hasCHOCH);
        out.hasOrderBlock = TelemetryEvidenceState(signal.hasOrderBlock);
        out.hasFVG = TelemetryEvidenceState(signal.hasFVG);
        out.hasProtectedPoint = TelemetryEvidenceState(signal.hasProtectedPoint);
        out.hasLiquiditySweep = TelemetryEvidenceState(signal.hasLiquiditySweep);

        out.signalTime = signal.time;

        //--- Schema v3.1 (TC01): structural split by component.
        out.layerOrderBlock = signal.score.layerOrderBlock;
        out.layerFVG        = signal.score.layerFVG;

        //--- FVG classifier + gap timestamps: TC04 serializes the FVG
        //    detector's classification; until then rows carry UNKNOWN/0.
        out.fvgClass       = "UNKNOWN";
        out.fvgSize        = "UNKNOWN";
        out.fvgStrength    = "UNKNOWN";
        out.fvgCreatedTime = 0;
        out.fvgFillTime    = 0;
        return true;
    }

    static string PackEvidenceIds(const int &evidenceIds[], const int count)
    {
        string out = "";
        for(int i = 0; i < count && i < MAX_EVIDENCE_IDS; i++)
        {
            if(out != "")
                out += ",";
            out += IntegerToString(evidenceIds[i]);
        }
        return out;
    }
};

#endif
