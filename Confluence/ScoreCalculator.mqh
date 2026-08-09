#ifndef __SCORE_CALCULATOR_MQH__
#define __SCORE_CALCULATOR_MQH__

#include "SignalTypes.mqh"
#include "ConfluenceWeights.mqh"
#include "../Structure/TrendState.mqh"

#define SCORE_STRUCTURAL_BOS       15
#define SCORE_STRUCTURAL_CHOCH     20
#define SCORE_STRUCTURAL_OB        15
#define SCORE_STRUCTURAL_FVG       10
#define SCORE_STRUCTURAL_PP        10
#define SCORE_STRUCTURAL_MAX       50

#define SCORE_LIQUIDITY_SWEPT      30
#define SCORE_LIQUIDITY_ACTIVE      5
#define SCORE_LIQUIDITY_MAX        30

#define SCORE_CONFIRMATION_MAX     20
#define SCORE_CONFIRMATION_TREND    5

int CalculateStructuralScore(bool hasBOS, bool hasCHOCH, bool hasOrderBlock,
                             bool hasFVG, bool hasProtectedPoint)
{
    int s = 0;
    if(hasBOS)            s += SCORE_STRUCTURAL_BOS;
    if(hasCHOCH)          s += SCORE_STRUCTURAL_CHOCH;
    if(hasOrderBlock)     s += SCORE_STRUCTURAL_OB;
    if(hasFVG)            s += SCORE_STRUCTURAL_FVG;
    if(hasProtectedPoint) s += SCORE_STRUCTURAL_PP;
    return fmin(s, SCORE_STRUCTURAL_MAX);
}

int CalculateLiquidityScore(bool hasSweep, bool mitigated)
{
    if(!hasSweep)
        return 0;
    if(mitigated)
        return 0;
    return SCORE_LIQUIDITY_SWEPT;
}

int CalculateConfirmationScore(int structuralScore, int liquidityScore,
                                bool trendAligned)
{
    int count = 0;
    if(structuralScore >= SCORE_STRUCTURAL_BOS)  count++;
    if(structuralScore >= SCORE_STRUCTURAL_BOS + SCORE_STRUCTURAL_CHOCH) count++;
    if(liquidityScore >= SCORE_LIQUIDITY_SWEPT) count++;

    int bonus = (count >= 2 ? 10 : 0) + (count >= 3 ? 10 : 0) + (trendAligned ? SCORE_CONFIRMATION_TREND : 0);
    return fmin(bonus, SCORE_CONFIRMATION_MAX);
}

ScoreLayer CalculateTotalScore(bool hasBOS, bool hasCHOCH, bool hasOrderBlock,
                                bool hasFVG, bool hasProtectedPoint,
                                bool hasSweep, bool mitigated,
                                bool trendAligned)
{
    ScoreLayer s;
    s.structural   = CalculateStructuralScore(hasBOS, hasCHOCH, hasOrderBlock, hasFVG, hasProtectedPoint);
    s.liquidity    = CalculateLiquidityScore(hasSweep, mitigated);
    s.confirmation = CalculateConfirmationScore(s.structural, s.liquidity, trendAligned);
    s.total        = fmin(s.structural + s.liquidity + s.confirmation, 100);
    //--- Schema v3.1 (TC01): structural split by component (additive).
    s.layerOrderBlock = hasOrderBlock ? SCORE_STRUCTURAL_OB : 0;
    s.layerFVG        = hasFVG ? SCORE_STRUCTURAL_FVG : 0;
    return s;
}

struct LayerResult
{
    int structural;
    int liquidity;
    int confirmation;
    int total;
    bool trendAligned;   // trend bonus actually applied (evidence flag for telemetry)
    int layerOrderBlock; // schema v3.1 (TC01): OB contribution to structural
    int layerFVG;        // schema v3.1 (TC01): FVG contribution to structural
};

LayerResult CalculateRuleLayers(const RuleResult &rule,
                                 CTrendState *trendState,
                                 CBOSDetector *bosDetector,
                                 COrderBlockDetector *obDetector,
                                 CFVGDetector *fvgDetector,
                                 CLiquidityDetector *liquidityDetector)
{
    LayerResult r;
    r.structural = 0;
    r.liquidity = 0;
    r.confirmation = 0;
    r.trendAligned = false;
    r.layerOrderBlock = 0;
    r.layerFVG = 0;

    if(!rule.matched)
    {
        r.total = 0;
        return r;
    }

    bool hasBOS = (rule.type == RULE_BOS_OB_BULLISH || rule.type == RULE_BOS_OB_BEARISH ||
                   rule.type == RULE_LIQUIDITY_BOS_BULLISH || rule.type == RULE_LIQUIDITY_BOS_BEARISH);
    bool hasOB = (rule.type == RULE_BOS_OB_BULLISH || rule.type == RULE_BOS_OB_BEARISH ||
                  rule.type == RULE_OB_FVG_BULLISH || rule.type == RULE_OB_FVG_BEARISH ||
                  rule.type == RULE_CHOCH_OB_REVERSAL);
    bool hasFVG = (rule.type == RULE_OB_FVG_BULLISH || rule.type == RULE_OB_FVG_BEARISH);
    bool hasCHOCH = (rule.type == RULE_CHOCH_OB_REVERSAL);
    bool hasLiquidity = (rule.type == RULE_LIQUIDITY_BOS_BULLISH || rule.type == RULE_LIQUIDITY_BOS_BEARISH);

    if(hasBOS)   r.structural += SCORE_STRUCTURAL_BOS;
    if(hasOB)    r.structural += SCORE_STRUCTURAL_OB;
    if(hasFVG)   r.structural += SCORE_STRUCTURAL_FVG;
    if(hasCHOCH) r.structural += SCORE_STRUCTURAL_CHOCH;
    r.structural = fmin(r.structural, SCORE_STRUCTURAL_MAX);

    //--- Schema v3.1 (TC01): structural split by component (additive).
    r.layerOrderBlock = hasOB ? SCORE_STRUCTURAL_OB : 0;
    r.layerFVG        = hasFVG ? SCORE_STRUCTURAL_FVG : 0;

    if(hasLiquidity)
        r.liquidity = SCORE_LIQUIDITY_SWEPT;

    int evidenceCount = 0;
    if(hasBOS)      evidenceCount++;
    if(hasOB)       evidenceCount++;
    if(hasFVG)      evidenceCount++;
    if(hasCHOCH)    evidenceCount++;
    if(hasLiquidity) evidenceCount++;

    if(evidenceCount >= 2) r.confirmation += 10;
    if(evidenceCount >= 3) r.confirmation += 10;

    if(trendState != NULL)
    {
        Trend current = trendState.GetCurrentTrend();
        bool trendAligned = (rule.direction == CONFLUENCE_BULLISH && current == TREND_BULLISH) ||
                            (rule.direction == CONFLUENCE_BEARISH && current == TREND_BEARISH);
        if(trendAligned)
        {
            r.confirmation += SCORE_CONFIRMATION_TREND;
            r.trendAligned = true;
        }
    }

    r.confirmation = fmin(r.confirmation, SCORE_CONFIRMATION_MAX);
    r.total = fmin(r.structural + r.liquidity + r.confirmation, 100);

    return r;
}

//--- TC02: rule-path component raw/weight/contribution wiring.  The
//    engine already computes the layer split (ScoreLayer); the legacy
//    6-component columns are derived from it at decision time using the
//    same formula the evaluator path uses (contribution = score * weight
//    / 100, weight from the configured ConfluenceWeights).  Only slices
//    with score > 0 become components (mirrors the evaluator path).
void BuildRulePathComponents(const ScoreLayer &score,
                             const ConfluenceWeights &weights,
                             ConfluenceComponentResult &components[],
                             int &compCount)
{
    compCount = 0;

    ENUM_CONFLUENCE_COMPONENT types[5] = { COMPONENT_STRUCTURE,
                                           COMPONENT_ORDER_BLOCK,
                                           COMPONENT_FVG,
                                           COMPONENT_LIQUIDITY,
                                           COMPONENT_TREND };
    double slices[5];
    slices[0] = (double)(score.structural - score.layerOrderBlock - score.layerFVG);
    slices[1] = (double)score.layerOrderBlock;
    slices[2] = (double)score.layerFVG;
    slices[3] = (double)score.liquidity;
    slices[4] = (score.trendAligned ? (double)SCORE_CONFIRMATION_TREND : 0.0);

    for(int i = 0; i < 5 && compCount < MAX_CONFLUENCE_COMPONENTS; i++)
    {
        if(slices[i] <= 0.0)
            continue;
        components[compCount].type = types[i];
        components[compCount].score = slices[i];
        components[compCount].weight = weights.GetWeight(types[i]);
        components[compCount].contribution = slices[i] * weights.GetWeight(types[i]) / 100.0;
        compCount++;
    }
}

#endif
