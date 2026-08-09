#ifndef __CONFLUENCE_RULES_MQH__
#define __CONFLUENCE_RULES_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Structure/TrendState.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "SignalTypes.mqh"

#define CONFLUENCE_RECENT_BARS 10
#define RULE_BASE_SCORE 70
#define EVIDENCE_FRESHNESS_THRESHOLD 20

bool TrendAligned(CTrendState *trendState, bool &outBullish, bool &outBearish)
{
    if(trendState == NULL)
        return false;

    Trend current = trendState.GetCurrentTrend();

    if(current == TREND_BULLISH)
    {
        outBullish = true;
        outBearish = false;
        return true;
    }

    if(current == TREND_BEARISH)
    {
        outBullish = false;
        outBearish = true;
        return true;
    }

    outBullish = false;
    outBearish = false;
    return false;
}

bool RecentBOS(CBOSDetector *bosDetector, bool bullish, int &outId)
{
    if(bosDetector == NULL)
        return false;

    int count = bosDetector.GetBOSCount();
    if(count == 0)
        return false;

    for(int i = count - 1; i >= 0; i--)
    {
        BOSEvent bos;
        if(!bosDetector.GetBOS(i, bos))
            continue;

        if(bos.bullish != bullish)
            continue;

        datetime cutoff = iTime(_Symbol, _Period, CONFLUENCE_RECENT_BARS);
        if(cutoff > 0 && bos.breakTime < cutoff)
            continue;

        outId = bos.id;
        return true;
    }
    return false;
}

bool RecentCHOCH(CCHOCHDetector *chochDetector, bool bullish, int &outId)
{
    if(chochDetector == NULL)
        return false;

    int count = chochDetector.GetCHOCHCount();
    if(count == 0)
        return false;

    for(int i = count - 1; i >= 0; i--)
    {
        CHOCHEvent choch;
        if(!chochDetector.GetCHOCH(i, choch))
            continue;

        if(choch.bullish != bullish)
            continue;

        datetime cutoff = iTime(_Symbol, _Period, CONFLUENCE_RECENT_BARS);
        if(cutoff > 0 && choch.time < cutoff)
            continue;

        outId = choch.id;
        return true;
    }
    return false;
}

bool ActiveOB(COrderBlockDetector *obDetector, bool bullish, int &outId)
{
    if(obDetector == NULL)
        return false;

    int count = obDetector.GetOrderBlockCount();
    for(int i = count - 1; i >= 0; i--)
    {
        OrderBlock ob;
        if(!obDetector.GetOrderBlock(i, ob))
            continue;

        if(ob.bullish != bullish)
            continue;

        if(ob.mitigated || ob.invalidated)
            continue;

        outId = ob.id;
        return true;
    }
    return false;
}

bool UntouchedFVG(CFVGDetector *fvgDetector, bool bullish, int &outId)
{
    if(fvgDetector == NULL)
        return false;

    int count = fvgDetector.GetFVGCount();
    for(int i = count - 1; i >= 0; i--)
    {
        FairValueGap fvg;
        if(!fvgDetector.GetFVG(i, fvg))
            continue;

        if(fvg.bullish != bullish)
            continue;

        if(fvg.filled)
            continue;

        outId = fvg.id;
        return true;
    }
    return false;
}

bool RecentLiquiditySweep(CLiquidityDetector *liquidityDetector, bool bullish,
                          int &outLevelId, bool &outMitigated)
{
    if(liquidityDetector == NULL)
        return false;

    int count = liquidityDetector.GetLevelCount();
    if(count == 0)
        return false;

    for(int i = count - 1; i >= 0; i--)
    {
        LiquidityLevel ll;
        if(!liquidityDetector.GetLevel(i, ll))
            continue;

        if(!ll.swept)
            continue;

        datetime cutoff = iTime(_Symbol, _Period, CONFLUENCE_RECENT_BARS);
        if(cutoff > 0 && ll.sweptTime < cutoff)
            continue;

        bool levelBullish = (ll.type == LIQUIDITY_EQH ||
                             ll.type == LIQUIDITY_INTERNAL_HH ||
                             ll.type == LIQUIDITY_EXTERNAL_HH);

        if(levelBullish != bullish)
            continue;

        outLevelId = ll.id;
        outMitigated = ll.mitigated;
        return true;
    }
    return false;
}

double ComputeFreshness(int evidenceAge)
{
    if(evidenceAge < 5)
        return 1.0;
    if(evidenceAge < 10)
        return 0.9;
    if(evidenceAge < 20)
        return 0.8;
    return 0.7;
}

int EstimateEvidenceAge(int evidenceId)
{
    return (int)(Bars(_Symbol, _Period) % EVIDENCE_FRESHNESS_THRESHOLD);
}

RuleResult BuildRejected(RuleType type, string reason)
{
    RuleResult result;
    result.matched = false;
    result.type = type;
    result.score = 0;
    result.confidence = 0.0;
    result.direction = CONFLUENCE_NONE;
    result.evidenceCount = 0;
    result.explanation = reason;
    result.timestamp = TimeCurrent();
    return result;
}

RuleResult BuildMatched(RuleType type, ConfluenceDirection dir,
                        int id1, int id2, int id3,
                        int score, double confidence, string explanation)
{
    RuleResult result;
    result.matched = true;
    result.type = type;
    result.score = score;
    result.confidence = confidence;
    result.direction = dir;
    result.timestamp = TimeCurrent();

    result.evidenceIds[0] = id1;
    result.evidenceCount = 1;
    if(id2 > 0)
    {
        result.evidenceIds[result.evidenceCount] = id2;
        result.evidenceCount++;
    }
    if(id3 > 0)
    {
        result.evidenceIds[result.evidenceCount] = id3;
        result.evidenceCount++;
    }

    result.explanation = explanation;
    return result;
}

RuleResult RuleBOS_OB_Bullish(CTrendState *trendState,
                              CBOSDetector *bosDetector,
                              COrderBlockDetector *obDetector)
{
    int bosId = -1, obId = -1;

    if(!RecentBOS(bosDetector, true, bosId))
        return BuildRejected(RULE_BOS_OB_BULLISH, "NoRecentBullishBOS");

    if(!ActiveOB(obDetector, true, obId))
        return BuildRejected(RULE_BOS_OB_BULLISH, "NoActiveBullishOB");

    int score = RULE_BASE_SCORE;

    double confidence = 0.85;
    bool trendBull = false, trendBear = false;
    if(TrendAligned(trendState, trendBull, trendBear) && trendBull)
    {
        score += 15;
        confidence += 0.10;
    }

    confidence = fmin(confidence, 0.99);

    string explanation = "Bullish BOS + Bullish OB";
    if(trendBull)
        explanation += " + Trend Alignment";

    return BuildMatched(RULE_BOS_OB_BULLISH, CONFLUENCE_BULLISH,
                        bosId, obId, -1,
                        score, confidence, explanation);
}

RuleResult RuleBOS_OB_Bearish(CTrendState *trendState,
                              CBOSDetector *bosDetector,
                              COrderBlockDetector *obDetector)
{
    int bosId = -1, obId = -1;

    if(!RecentBOS(bosDetector, false, bosId))
        return BuildRejected(RULE_BOS_OB_BEARISH, "NoRecentBearishBOS");

    if(!ActiveOB(obDetector, false, obId))
        return BuildRejected(RULE_BOS_OB_BEARISH, "NoActiveBearishOB");

    int score = RULE_BASE_SCORE;

    double confidence = 0.85;
    bool trendBull = false, trendBear = false;
    if(TrendAligned(trendState, trendBull, trendBear) && trendBear)
    {
        score += 15;
        confidence += 0.10;
    }

    confidence = fmin(confidence, 0.99);

    string explanation = "Bearish BOS + Bearish OB";
    if(trendBear)
        explanation += " + Trend Alignment";

    return BuildMatched(RULE_BOS_OB_BEARISH, CONFLUENCE_BEARISH,
                        bosId, obId, -1,
                        score, confidence, explanation);
}

RuleResult RuleOB_FVG_Bullish(COrderBlockDetector *obDetector,
                              CFVGDetector *fvgDetector)
{
    int obId = -1, fvgId = -1;

    if(!ActiveOB(obDetector, true, obId))
        return BuildRejected(RULE_OB_FVG_BULLISH, "NoActiveBullishOB");

    if(!UntouchedFVG(fvgDetector, true, fvgId))
        return BuildRejected(RULE_OB_FVG_BULLISH, "NoUntouchedBullishFVG");

    int score = RULE_BASE_SCORE;
    double confidence = 0.80;

    string explanation = "Bullish OB + Untouched Bullish FVG";

    return BuildMatched(RULE_OB_FVG_BULLISH, CONFLUENCE_BULLISH,
                        obId, fvgId, -1,
                        score, confidence, explanation);
}

RuleResult RuleOB_FVG_Bearish(COrderBlockDetector *obDetector,
                              CFVGDetector *fvgDetector)
{
    int obId = -1, fvgId = -1;

    if(!ActiveOB(obDetector, false, obId))
        return BuildRejected(RULE_OB_FVG_BEARISH, "NoActiveBearishOB");

    if(!UntouchedFVG(fvgDetector, false, fvgId))
        return BuildRejected(RULE_OB_FVG_BEARISH, "NoUntouchedBearishFVG");

    int score = RULE_BASE_SCORE;
    double confidence = 0.80;

    string explanation = "Bearish OB + Untouched Bearish FVG";

    return BuildMatched(RULE_OB_FVG_BEARISH, CONFLUENCE_BEARISH,
                        obId, fvgId, -1,
                        score, confidence, explanation);
}

RuleResult RuleLiquidity_BOS_Bullish(CTrendState *trendState,
                                     CLiquidityDetector *liquidityDetector,
                                     CBOSDetector *bosDetector)
{
    int levelId = -1, bosId = -1;
    bool mitigated = false;

    if(!RecentLiquiditySweep(liquidityDetector, true, levelId, mitigated))
        return BuildRejected(RULE_LIQUIDITY_BOS_BULLISH, "NoRecentBullishLiquiditySweep");

    if(!RecentBOS(bosDetector, true, bosId))
        return BuildRejected(RULE_LIQUIDITY_BOS_BULLISH, "NoRecentBullishBOS");

    int score = RULE_BASE_SCORE;
    double confidence = 0.80;

    if(!mitigated)
    {
        score += 10;
        confidence += 0.10;
    }

    bool trendBull = false, trendBear = false;
    if(TrendAligned(trendState, trendBull, trendBear) && trendBull)
    {
        score += 10;
        confidence += 0.05;
    }

    confidence = fmin(confidence, 0.99);

    string explanation = "Bullish Liquidity Sweep + Bullish BOS";
    if(!mitigated)
        explanation += " + Fresh Sweep";
    if(trendBull)
        explanation += " + Trend Alignment";

    return BuildMatched(RULE_LIQUIDITY_BOS_BULLISH, CONFLUENCE_BULLISH,
                        levelId, bosId, -1,
                        score, confidence, explanation);
}

RuleResult RuleLiquidity_BOS_Bearish(CTrendState *trendState,
                                     CLiquidityDetector *liquidityDetector,
                                     CBOSDetector *bosDetector)
{
    int levelId = -1, bosId = -1;
    bool mitigated = false;

    if(!RecentLiquiditySweep(liquidityDetector, false, levelId, mitigated))
        return BuildRejected(RULE_LIQUIDITY_BOS_BEARISH, "NoRecentBearishLiquiditySweep");

    if(!RecentBOS(bosDetector, false, bosId))
        return BuildRejected(RULE_LIQUIDITY_BOS_BEARISH, "NoRecentBearishBOS");

    int score = RULE_BASE_SCORE;
    double confidence = 0.80;

    if(!mitigated)
    {
        score += 10;
        confidence += 0.10;
    }

    bool trendBull = false, trendBear = false;
    if(TrendAligned(trendState, trendBull, trendBear) && trendBear)
    {
        score += 10;
        confidence += 0.05;
    }

    confidence = fmin(confidence, 0.99);

    string explanation = "Bearish Liquidity Sweep + Bearish BOS";
    if(!mitigated)
        explanation += " + Fresh Sweep";
    if(trendBear)
        explanation += " + Trend Alignment";

    return BuildMatched(RULE_LIQUIDITY_BOS_BEARISH, CONFLUENCE_BEARISH,
                        levelId, bosId, -1,
                        score, confidence, explanation);
}

RuleResult RuleCHOCH_OB_Reversal(CCHOCHDetector *chochDetector,
                                 COrderBlockDetector *obDetector)
{
    int chochId = -1, obId = -1;

    if(!RecentCHOCH(chochDetector, true, chochId))
        return BuildRejected(RULE_CHOCH_OB_REVERSAL, "NoRecentBullishCHOCH");

    if(!ActiveOB(obDetector, false, obId))
        return BuildRejected(RULE_CHOCH_OB_REVERSAL, "NoActiveBearishOB");

    int score = RULE_BASE_SCORE + 5;
    double confidence = 0.75;

    string explanation = "Bullish CHOCH + Bearish OB (Potential Reversal)";

    return BuildMatched(RULE_CHOCH_OB_REVERSAL, CONFLUENCE_BULLISH,
                        chochId, obId, -1,
                        score, confidence, explanation);
}

#endif
