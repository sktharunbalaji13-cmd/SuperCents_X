#ifndef __ENTRY_DECISION_RULES_MQH__
#define __ENTRY_DECISION_RULES_MQH__

#include "EntryDecisionTypes.mqh"

struct GateResult
{
    bool   passed;
    bool   applicable;
    string explanation;
};

struct DecisionGates
{
    GateResult scoreGate;
    GateResult confidenceGate;
    GateResult evidenceGate;
    GateResult ruleGate;
    GateResult trendGate;
};

bool CheckScoreGate(const TradeCandidate &candidate, int threshold, GateResult &out)
{
    if (threshold <= 0)
    {
        out.passed = true;
        out.applicable = false;
        out.explanation = "";
        return true;
    }

    out.applicable = true;
    out.passed = candidate.score >= threshold;

    if (out.passed)
        out.explanation = StringFormat("Score %d >= %d", candidate.score, threshold);
    else
        out.explanation = StringFormat("Score %d < %d", candidate.score, threshold);

    return out.passed;
}

bool CheckConfidenceGate(const TradeCandidate &candidate, double threshold, GateResult &out)
{
    if (threshold <= 0.0)
    {
        out.passed = true;
        out.applicable = false;
        out.explanation = "";
        return true;
    }

    out.applicable = true;
    out.passed = candidate.confidence >= threshold;

    if (out.passed)
        out.explanation = StringFormat("Confidence %.2f >= %.2f", candidate.confidence, threshold);
    else
        out.explanation = StringFormat("Confidence %.2f < %.2f", candidate.confidence, threshold);

    return out.passed;
}

bool CheckEvidenceGate(const TradeCandidate &candidate, int threshold, GateResult &out)
{
    if (threshold <= 0)
    {
        out.passed = true;
        out.applicable = false;
        out.explanation = "";
        return true;
    }

    out.applicable = true;
    out.passed = candidate.evidenceCount >= threshold;

    if (out.passed)
        out.explanation = StringFormat("%d evidence sources >= %d", candidate.evidenceCount, threshold);
    else
        out.explanation = StringFormat("%d evidence sources < %d", candidate.evidenceCount, threshold);

    return out.passed;
}

bool CheckRuleGate(const TradeCandidate &candidate, int threshold, GateResult &out)
{
    if (threshold <= 0)
    {
        out.passed = true;
        out.applicable = false;
        out.explanation = "";
        return true;
    }

    out.applicable = true;
    out.passed = candidate.ruleCount >= threshold;

    if (out.passed)
        out.explanation = StringFormat("%d matching rules >= %d", candidate.ruleCount, threshold);
    else
        out.explanation = StringFormat("%d matching rules < %d", candidate.ruleCount, threshold);

    return out.passed;
}

#endif
