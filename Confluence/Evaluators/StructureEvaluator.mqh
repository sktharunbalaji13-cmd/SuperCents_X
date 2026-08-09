#ifndef __STRUCTURE_EVALUATOR_MQH__
#define __STRUCTURE_EVALUATOR_MQH__

#include "IConfluenceEvaluator.mqh"
#include "../../Structure/BOSDetector.mqh"
#include "../../Structure/CHOCHDetector.mqh"
#include "../../Structure/ProtectedPointManager.mqh"

#define STRUCT_RECENT_BARS 10

class CStructureEvaluator : public IConfluenceEvaluator
{
private:
    bool HasRecentBOS(const CBOSDetector *detector, bool bullish, int &outId) const
    {
        if(detector == NULL) return false;
        int count = detector.GetBOSCount();
        if(count == 0) return false;
        for(int i = count - 1; i >= 0; i--)
        {
            BOSEvent bos;
            if(!detector.GetBOS(i, bos)) continue;
            if(bos.bullish != bullish) continue;
            datetime cutoff = iTime(_Symbol, _Period, STRUCT_RECENT_BARS);
            if(cutoff > 0 && bos.breakTime < cutoff) continue;
            outId = bos.id;
            return true;
        }
        return false;
    }

    bool HasRecentCHOCH(const CCHOCHDetector *detector, bool bullish, int &outId) const
    {
        if(detector == NULL) return false;
        int count = detector.GetCHOCHCount();
        if(count == 0) return false;
        for(int i = count - 1; i >= 0; i--)
        {
            CHOCHEvent choch;
            if(!detector.GetCHOCH(i, choch)) continue;
            if(choch.bullish != bullish) continue;
            datetime cutoff = iTime(_Symbol, _Period, STRUCT_RECENT_BARS);
            if(cutoff > 0 && choch.time < cutoff) continue;
            outId = choch.id;
            return true;
        }
        return false;
    }

    bool HasProtectedPoint(const CProtectedPointManager *pp, bool bullish) const
    {
        if(pp == NULL) return false;
        ProtectedPoint pt;
        if(bullish)
            return pp.GetActiveHigh(pt);
        else
            return pp.GetActiveLow(pt);
    }

public:
    bool Evaluate(const DetectionContext &context, ConfluenceComponentResult &result)
    {
        result.type = COMPONENT_STRUCTURE;

        int bosId = -1, chochId = -1;
        bool hasBullishBOS = HasRecentBOS(context.bosDetector, true, bosId);
        bool hasBearishBOS = HasRecentBOS(context.bosDetector, false, bosId);
        bool hasBullishCHOCH = HasRecentCHOCH(context.chochDetector, true, chochId);
        bool hasBearishCHOCH = HasRecentCHOCH(context.chochDetector, false, chochId);
        bool hasBullishPP = HasProtectedPoint(context.protectedPointManager, true);
        bool hasBearishPP = HasProtectedPoint(context.protectedPointManager, false);

        double score = 0.0;
        string expl = "";
        int count = 0;

        if(hasBullishBOS || hasBearishBOS)
        {
            score += 35.0;
            count++;
            expl = hasBullishBOS ? "BullishBOS" : "BearishBOS";
        }

        if(hasBullishCHOCH || hasBearishCHOCH)
        {
            score += 30.0;
            count++;
            if(expl != "") expl += "+";
            expl += hasBullishCHOCH ? "CHOCH" : "BearishCHOCH";
        }

        if(hasBullishPP || hasBearishPP)
        {
            score += 20.0;
            count++;
        }

        if(count >= 2)
            score += 15.0;

        if(count >= 3)
            score += 10.0;

        result.score = fmin(100.0, score);
        result.explanation = expl != "" ? expl : "NoStructureConfluence";
        return result.score > 0.0;
    }

    ENUM_CONFLUENCE_COMPONENT GetComponentType(void) const
    {
        return COMPONENT_STRUCTURE;
    }

    string GetName(void) const
    {
        return "StructureEvaluator";
    }

    string GetVersion(void) const
    {
        return "1.0.0";
    }

    string GetDescription(void) const
    {
        return "Scores structural confluence from BOS/CHOCH recency and protected point validity";
    }
};

#endif
