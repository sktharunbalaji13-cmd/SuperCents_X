#ifndef __ENTRY_CONFIG_MQH__
#define __ENTRY_CONFIG_MQH__

#include "../Confluence/SignalTypes.mqh"
#include "EntryTypes.mqh"

//+------------------------------------------------------------------+
//| Entry mode matrix (Sprint 15, v3.0)                               |
//|                                                                  |
//|  Mode      Providers        Entry Engine  Real Orders  Shadow Tlm |
//|  LEGACY    Shadow/Legacy    Legacy        Legacy        No        |
//|  SHADOW    Shadow           New           No            Yes       |
//|  NEW       Production       New           No (reserved) Yes       |
//|  LIVE(*)   Production       New           Yes           Yes       |
//|                                                                  |
//|  (*) ENTRY_MODE_LIVE is a future post-promotion mode (Sprint 16+);|
//|      execution stays disabled until the promotion gate passes.   |
//|                                                                  |
//|  Providers follow the @frozen v3.0-provider-contract: they       |
//|  retrieve state only; validators hold all business rules.        |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE
{
    ENTRY_MODE_LEGACY = 0,
    ENTRY_MODE_SHADOW,
    ENTRY_MODE_NEW
};

struct ShadowComparison
{
    //--- format 1 (v2.9): legacy side inferred from plan existence; legacyConfidence 0-100.
    //--- format 2 (v2.9.2): legacy side is the decision-level status; both confidences 0-1.
    uint                        formatVersion;
    datetime                    timestamp;
    string                      symbol;
    ENUM_TIMEFRAMES             timeframe;
    string                      eaVersion;
    bool                        decisionMatch;
    bool                        directionMatch;
    ENUM_ENTRY_REJECTION_REASON legacyFirstReason;
    ENUM_ENTRY_REJECTION_REASON newFirstReason;
    double                      legacyConfidence;
    double                      newConfidence;
    uint                        validationTimeUs;

    ShadowComparison(void)
        : formatVersion(2)
        , timestamp(0)
        , symbol("")
        , timeframe(PERIOD_CURRENT)
        , eaVersion("")
        , decisionMatch(false)
        , directionMatch(false)
        , legacyFirstReason(REASON_NONE)
        , newFirstReason(REASON_NONE)
        , legacyConfidence(0.0)
        , newConfidence(0.0)
        , validationTimeUs(0)
    {}
};

#endif