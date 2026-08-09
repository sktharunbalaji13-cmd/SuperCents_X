#ifndef __ENTRY_LOGGER_MQH__
#define __ENTRY_LOGGER_MQH__

#include "EntryTypes.mqh"
#include "EntryDecisionTypes.mqh"
#include "EntryConfig.mqh"

class CEntryLogger
{
public:
    void LogValidationStart(int validatorCount) const
    {
        Print("[EntryEngine] Running " + IntegerToString(validatorCount) + " validators");
    }

    void LogFilterResult(const EntryFilterResult &filter) const
    {
        string resultStr = "";
        if(filter.result == FILTER_PASS)
            resultStr = "PASS";
        else if(filter.result == FILTER_WARNING)
            resultStr = "WARNING";
        else
            resultStr = "FAIL";

        Print("[EntryEngine] Validator '" + filter.validatorName
            + "' [" + resultStr + "] " + filter.explanation);
    }

    void LogDecision(const EntryDecision &decision) const
    {
        string statusStr = "";
        if(decision.status == DECISION_QUALIFIED)
            statusStr = "QUALIFIED";
        else if(decision.status == DECISION_REJECTED)
            statusStr = "REJECTED";
        else
            statusStr = "CREATED";

        string directionStr = "";
        if(decision.direction == CONFLUENCE_BULLISH)
            directionStr = "BUY";
        else if(decision.direction == CONFLUENCE_BEARISH)
            directionStr = "SELL";
        else
            directionStr = "NONE";

        Print("[EntryEngine] Decision #" + IntegerToString(decision.candidateId)
            + " " + directionStr + " " + statusStr
            + " confidence=" + DoubleToString(decision.confidence, 2)
            + " score=" + IntegerToString(decision.decisionScore));

        if(decision.rejectionCount > 0)
        {
            Print("[EntryEngine] Rejection reasons (" + IntegerToString(decision.rejectionCount) + "):");
            for(int i = 0; i < decision.rejectionCount && i < MAX_REJECTION_REASONS; i++)
            {
                if(decision.rejectionReasons[i] != "")
                    Print("  " + IntegerToString(i + 1) + ". " + decision.rejectionReasons[i]);
            }
        }
    }

    void LogShadowComparison(const EntryDecision &legacy, const EntryDecision &modern, int &agreementCount, int &totalCount) const
    {
        totalCount++;
        bool directionMatch = (legacy.direction == modern.direction);
        bool statusMatch = (legacy.status == modern.status);
        bool agreed = directionMatch && statusMatch;

        if(agreed)
            agreementCount++;

        Print("[ShadowMode] Decision #" + IntegerToString(legacy.candidateId)
            + " direction=" + (directionMatch ? "OK" : "MISMATCH")
            + " status=" + (statusMatch ? "OK" : "MISMATCH")
            + (agreed ? " AGREED" : " DISAGREED")
            + " (agreement=" + IntegerToString(agreementCount) + "/" + IntegerToString(totalCount) + ")");
    }

    void LogShadowComparisonStruct(const ShadowComparison &cmp) const
    {
        string tfStr = StringFormat("TF%d", cmp.timeframe);
        Print("[Shadow] fmt=" + IntegerToString(cmp.formatVersion)
            + " sym=" + cmp.symbol
            + " tf=" + tfStr
            + " ver=" + cmp.eaVersion
            + " dec=" + (cmp.decisionMatch ? "MATCH" : "MISMATCH")
            + " dir=" + (cmp.directionMatch ? "MATCH" : "MISMATCH")
            + " legacyConf=" + DoubleToString(cmp.legacyConfidence, 2)
            + " newConf=" + DoubleToString(cmp.newConfidence, 2)
            + " timeUs=" + IntegerToString(cmp.validationTimeUs));
    }

    void LogShadowSummary(int totalDecisions, int agreements, double agreementPct) const
    {
        Print("");
        Print("[ShadowMode] === Shadow Mode Summary ===");
        Print("[ShadowMode] Total Decisions: " + IntegerToString(totalDecisions));
        Print("[ShadowMode] Agreements: " + IntegerToString(agreements));
        Print("[ShadowMode] Agreement %: " + DoubleToString(agreementPct, 1) + "%");
        Print("[ShadowMode] =============================");
    }
};

#endif
