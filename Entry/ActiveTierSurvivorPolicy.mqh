//+------------------------------------------------------------------+
//|                        ActiveTierSurvivorPolicy.mqh               |
//|                                      Copyright 2026, SuperCents_X|
//|                                 P31 — ACTIVE-TIER survivor policy |
//+------------------------------------------------------------------+
//  P30 policy, verbatim: one decision per global signalTime; the
//  survivor is selected by highest ConfluenceResult-level confidence
//  (totalConfidence); ties within ACTIVE_TIER_CONF_TIE_EPS (1e-9) are
//  resolved by the smallest decisionId. Missing/invalid confidence
//  normalizes to 0.0 (P30-defined). Deterministic and order-independent
//  by the pairwise fold: the survivor after any candidate sequence is
//  the maximum-confidence candidate, smallest decisionId among
//  confidence ties. Fixed policy — no parameters. Direction is NOT a
//  ranking criterion (opposite-direction candidates do not coexist at
//  the same signalTime).
//
//  Scope (P31): ACTIVE-TIER admission boundary only
//  (Portfolio/SymbolContext.mqh, SwingGateEvaluate -> Evaluate path).
//+------------------------------------------------------------------+
#ifndef __ACTIVE_TIER_SURVIVOR_POLICY_MQH__
#define __ACTIVE_TIER_SURVIVOR_POLICY_MQH__

#define ACTIVE_TIER_CONF_TIE_EPS 1e-9

//--- P30: missing/invalid confidence normalizes to 0.0
double ActiveTierSurvivor_NormalizeConfidence(const double c)
{
    if(!MathIsValidNumber(c)) return 0.0;
    if(c == EMPTY_VALUE)      return 0.0;
    if(c < 0.0)               return 0.0;
    return c;
}

//--- P30 survivor rule (pairwise): does the challenger supersede the
//    incumbent? Confidence differing by more than
//    ACTIVE_TIER_CONF_TIE_EPS -> the higher confidence wins; within the
//    window -> the smallest decisionId wins.
bool ActiveTierSurvivor_ChallengerWins(const double incumbentConf,
                                       const long   incumbentId,
                                       const double challengerConf,
                                       const long   challengerId)
{
    const double ic = ActiveTierSurvivor_NormalizeConfidence(incumbentConf);
    const double cc = ActiveTierSurvivor_NormalizeConfidence(challengerConf);
    if(MathAbs(cc - ic) <= ACTIVE_TIER_CONF_TIE_EPS)
        return (challengerId < incumbentId);
    return (cc > ic);
}

#endif // __ACTIVE_TIER_SURVIVOR_POLICY_MQH__
