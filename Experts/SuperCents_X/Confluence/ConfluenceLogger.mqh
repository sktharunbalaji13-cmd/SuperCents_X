#ifndef __CONFLUENCE_LOGGER_MQH__
#define __CONFLUENCE_LOGGER_MQH__

#include "../Core/Logger.mqh"
#include "ConfluenceTypes.mqh"
#include "ConfluenceWeights.mqh"

class CConfluenceLogger
{
private:
    CLogger m_logger;

public:
    CConfluenceLogger(void)
        : m_logger(MODULE_CONFLUENCE_ENGINE, "Confluence")
    {}

    void LogEvaluation(const ConfluenceResult &result)
    {
        if(!result.valid)
        {
            m_logger.LogInfo("Confluence: No valid setup (all components scored 0)");
            return;
        }

        string dirStr = (result.direction == CONFLUENCE_BULLISH ? "BULLISH" :
                         result.direction == CONFLUENCE_BEARISH ? "BEARISH" : "NONE");

        m_logger.LogInfo(StringFormat("Confluence: %s confidence=%.1f/100 | %s",
                         dirStr, result.totalConfidence, result.summaryExplanation));

        for(int i = 0; i < result.componentCount; i++)
        {
            ConfluenceComponentResult c = result.components[i];
            if(c.score > 0.0)
            {
                m_logger.LogDebug(StringFormat("  + %s: score=%.1f weight=%.1f%% contrib=%.1f | %s",
                    ComponentName(c.type), c.score, c.weight, c.contribution, c.explanation));
            }
            else
            {
                m_logger.LogDebug(StringFormat("  - %s: score=%.1f (no confluence)", ComponentName(c.type)));
            }
        }
    }

    static string ComponentName(ENUM_CONFLUENCE_COMPONENT type)
    {
        switch(type)
        {
            case COMPONENT_STRUCTURE:        return "Structure";
            case COMPONENT_TREND:            return "Trend";
            case COMPONENT_ORDER_BLOCK:      return "OrderBlock";
            case COMPONENT_FVG:              return "FVG";
            case COMPONENT_LIQUIDITY:        return "Liquidity";
            case COMPONENT_PREMIUM_DISCOUNT: return "PremiumDiscount";
            default: return "Unknown";
        }
    }
};

#endif
