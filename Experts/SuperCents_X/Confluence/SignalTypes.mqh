#ifndef __SIGNAL_TYPES_MQH__
#define __SIGNAL_TYPES_MQH__

#define MAX_EVIDENCE_IDS 5
#define MAX_CANDIDATE_RULES 7
#define MAX_CANDIDATE_EVIDENCE 20

enum ConfluenceDirection
{
    CONFLUENCE_NONE    = 0,
    CONFLUENCE_BULLISH = 1,
    CONFLUENCE_BEARISH = 2
};

enum SignalLifecycleState
{
    SIGNAL_ACTIVE = 0,
    SIGNAL_EXPIRED
};

enum ExpiryReason
{
    EXPIRY_NONE               = 0,
    EXPIRY_FVG_FILLED,
    EXPIRY_OB_MITIGATED,
    EXPIRY_OB_INVALIDATED,
    EXPIRY_LIQUIDITY_MITIGATED,
    EXPIRY_LIQUIDITY_INVALIDATED,
    EXPIRY_TREND_REVERSAL
};

enum RuleType
{
    RULE_NONE                 = 0,
    RULE_BOS_OB_BULLISH,
    RULE_BOS_OB_BEARISH,
    RULE_OB_FVG_BULLISH,
    RULE_OB_FVG_BEARISH,
    RULE_LIQUIDITY_BOS_BULLISH,
    RULE_LIQUIDITY_BOS_BEARISH,
    RULE_CHOCH_OB_REVERSAL
};

enum CandidateStatus
{
    CANDIDATE_CREATED = 0,
    CANDIDATE_ACTIVE,
    CANDIDATE_EXPIRED
};

struct TradeCandidate
{
    int                 id;
    ConfluenceDirection direction;
    int                 score;
    double              confidence;
    RuleType            matchedRules[MAX_CANDIDATE_RULES];
    int                 ruleCount;
    int                 evidenceIds[MAX_CANDIDATE_EVIDENCE];
    int                 evidenceCount;
    datetime            createdTime;
    CandidateStatus     status;
    string              rationale;

    bool hasBOS;
    bool hasCHOCH;
    bool hasOB;
    bool hasFVG;
    bool hasLiquidity;
    int  bosId;
    int  chochId;
    int  obId;
    int  fvgId;
    int  liquidityId;

    string ToString(void) const
    {
        return StringFormat("CANDIDATE #%d dir=%s score=%d conf=%.2f rules=%d ev=%d %s",
                            id,
                            (direction == CONFLUENCE_BULLISH ? "BULL" :
                             direction == CONFLUENCE_BEARISH ? "BEAR" : "NONE"),
                            score, confidence, ruleCount, evidenceCount, rationale);
    }
};

struct ScoreLayer
{
    int structural;
    int liquidity;
    int confirmation;
    int total;
    bool trendAligned;   // trend bonus actually applied (v3 evidence flag)

    ScoreLayer(void)
        : structural(0)
        , liquidity(0)
        , confirmation(0)
        , total(0)
        , trendAligned(false)
    {}

    string ToString(void) const
    {
        return StringFormat("S=%d L=%d C=%d T=%d", structural, liquidity, confirmation, total);
    }
};

struct RuleResult
{
    bool                matched;
    RuleType            type;
    int                 score;
    double              confidence;
    ConfluenceDirection direction;
    int                 evidenceIds[MAX_EVIDENCE_IDS];
    int                 evidenceCount;
    string              explanation;
    datetime            timestamp;

    string ToString(void) const
    {
        if(!matched)
            return StringFormat("RULE-REJECT type=%d", type);
        return StringFormat("RULE-MATCH type=%d dir=%s score=%d conf=%.2f ev=[%s] %s",
                            type,
                            (direction == CONFLUENCE_BULLISH ? "BULL" :
                             direction == CONFLUENCE_BEARISH ? "BEAR" : "NONE"),
                            score, confidence, EvidenceIdsToString(), explanation);
    }

    string EvidenceIdsToString(void) const
    {
        string out = "";
        for(int i = 0; i < evidenceCount; i++)
        {
            if(i > 0) out += ",";
            out += IntegerToString(evidenceIds[i]);
        }
        return out;
    }
};

struct ConfluenceSignal
{
    int       id;
    datetime  time;
    double    price;

    ConfluenceDirection   direction;
    SignalLifecycleState  lifecycle;
    ExpiryReason          expiryReason;

    ScoreLayer score;
    RuleResult currentRule;

    bool hasBOS;
    bool hasCHOCH;
    bool hasOrderBlock;
    bool hasFVG;
    bool hasProtectedPoint;
    bool hasLiquiditySweep;
    bool trendAligned;   // trend bonus applied by the layer score (v3 evidence)

    int  bosId;
    int  chochId;
    int  orderBlockId;
    int  fvgId;
    int  protectedPointId;
    int  liquidityLevelId;
};

#endif
