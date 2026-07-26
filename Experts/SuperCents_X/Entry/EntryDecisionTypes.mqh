#ifndef __ENTRY_DECISION_TYPES_MQH__
#define __ENTRY_DECISION_TYPES_MQH__

#include "../Confluence/SignalTypes.mqh"

#define MAX_REJECTION_REASONS 5

enum EntryDecisionStatus
{
    DECISION_CREATED = 0,
    DECISION_QUALIFIED,
    DECISION_REJECTED
};

struct EntryDecisionConfig
{
    int     minDecisionScore;
    double  minConfidence;
    int     minEvidenceSources;
    int     minRuleMatches;
    bool    requireTrendAlignment;

    EntryDecisionConfig(void)
        : minDecisionScore(70)
        , minConfidence(0.75)
        , minEvidenceSources(2)
        , minRuleMatches(1)
        , requireTrendAlignment(false)
    {}
};

struct EntryDecision
{
    int                 candidateId;
    ConfluenceDirection direction;
    EntryDecisionStatus status;
    int                 decisionScore;
    double              confidence;
    string              rationale;
    string              rejectionReasons[MAX_REJECTION_REASONS];
    int                 rejectionCount;
    datetime            createdTime;

    int     evidenceCount;
    int     ruleCount;
};

#endif
