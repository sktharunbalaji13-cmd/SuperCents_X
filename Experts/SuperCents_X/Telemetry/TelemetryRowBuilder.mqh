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

        //--- Outcome simulation is wired in a later sprint; schema fields
        //    stay at their UNKNOWN / NONE defaults for v2.9.2.
        return true;
    }
};

#endif
