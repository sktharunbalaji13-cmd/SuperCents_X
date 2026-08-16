//+------------------------------------------------------------------+
//|                     CExecutionPlanInspection.mqh                  |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03C-E |
//+------------------------------------------------------------------+
//  B25-03C-E - Plan-Identity Ledger Inspection (cross-run duplicate defense).
//
//  Corrected contract (C1): the inspection keys on the DURABLE canonical
//  plan identity (INTENT [8..12] + symbol/side/magic/sl/tp) read from the
//  UNBOUNDED ledger fold - NOT candidateId, NOT the bounded broker-history
//  window, NOT the live requestedPrice.
//
//  Verdicts (BLOCK over GUESS):
//    MATCHED      exact PI match against a prior broker-visible INTENT -> BLOCK
//    AMBIGUOUS    near match, legacy PI (absent), or current PI undefined -> BLOCK
//    NOT_FOUND    exhaustive ledger scan found no match -> SEND (safe)
//    CORRUPT      ledger unavailable/corrupt -> BLOCK
//
//  Read-only: no OrderSend, no broker mutation, no retry, no resend.
//+------------------------------------------------------------------+
#ifndef __EXECUTION_PLAN_INSPECTION_MQH__
#define __EXECUTION_PLAN_INSPECTION_MQH__

#include "CExecutionRecovery.mqh"

#define EINSPECT_MATCHED    "MATCHED"
#define EINSPECT_AMBIGUOUS  "AMBIGUOUS"
#define EINSPECT_NOT_FOUND  "NOT_FOUND"
#define EINSPECT_CORRUPT    "CORRUPT"
#define EINSPECT_UNAVAILABLE "UNAVAILABLE"

//--- pure PI comparison.  cur.present must be true.  prior.present=false
//    (legacy record) -> AMBIGUOUS (cannot prove non-duplicate).
string ComparePlanIdentity(const PlanIdentity &cur, const PlanIdentity &prior, const double eps)
{
    if(!prior.present)
        return EINSPECT_AMBIGUOUS;

    bool sameCore = (cur.symbol == prior.symbol && cur.side == prior.side &&
                     cur.magic == prior.magic &&
                     cur.entryPolicy == prior.entryPolicy &&
                     cur.stopPolicy == prior.stopPolicy &&
                     cur.targetPolicy == prior.targetPolicy);

    if(sameCore &&
       MathAbs(cur.planEntryPrice - prior.planEntryPrice) <= 1e-9 &&
       MathAbs(cur.stopLoss - prior.stopLoss) <= 1e-9 &&
       MathAbs(cur.takeProfit - prior.takeProfit) <= 1e-9)
        return EINSPECT_MATCHED;

    if(sameCore &&
       (MathAbs(cur.planEntryPrice - prior.planEntryPrice) <= eps ||
        MathAbs(cur.stopLoss - prior.stopLoss) <= eps ||
        MathAbs(cur.takeProfit - prior.takeProfit) <= eps))
        return EINSPECT_AMBIGUOUS;

    return EINSPECT_NOT_FOUND;
}

//--- locate the INTENT payload for an executionId in the replayed events.
string FindIntentPayload(const ExecutionLedgerEvent &events[], const string executionId)
{
    for(int i = 0; i < ArraySize(events); i++)
        if(events[i].eventType == LEDGER_EVENT_INTENT && events[i].executionId == executionId)
            return events[i].payload;
    return "";
}

class CExecutionPlanInspection
{
private:
    string m_ledgerPath;

public:
    void Init(const string ledgerPath) { m_ledgerPath = ledgerPath; }

    // Ledger-backed inspection.  Returns MATCHED / AMBIGUOUS / NOT_FOUND /
    // CORRUPT.  The current plan's PI is supplied by the caller.
    string Inspect(const string symbol, const string side, const long magic,
                   const int entryPolicy, const double planEntryPrice,
                   const int stopPolicy, const double stopLoss,
                   const int targetPolicy, const double takeProfit,
                   const bool structureResolved)
    {
        // current plan has no reproducible identity -> block (never guess)
        if(!structureResolved)
            return EINSPECT_AMBIGUOUS;

        PlanIdentity cur;
        cur.symbol = symbol;
        cur.side = side;
        cur.magic = magic;
        cur.entryPolicy = entryPolicy;
        cur.planEntryPrice = planEntryPrice;
        cur.stopPolicy = stopPolicy;
        cur.stopLoss = stopLoss;
        cur.targetPolicy = targetPolicy;
        cur.takeProfit = takeProfit;
        cur.structureResolved = true;
        cur.present = true;

        // Ledger missing at inspection time is NOT a proof of a first run:
        // the writer creates the ledger at Init, so a missing file here means
        // the durable evidence source was lost after creation.  A genuine first
        // run has an EXISTING empty ledger (header only) -> CLEAN scan, 0 events
        // -> NOT_FOUND.  A missing ledger -> UNAVAILABLE -> BLOCK (never guess).
        if(!FileIsExist(m_ledgerPath, FILE_COMMON))
            return EINSPECT_UNAVAILABLE;

        ExecutionLedgerEvent events[];
        string info = "";
        ENUM_LEDGER_SCAN_RESULT sc = LedgerScan(m_ledgerPath, events, info);
        if(sc != LEDGER_SCAN_CLEAN)
            return EINSPECT_CORRUPT;

        ExecutionReconState states[];
        string violation = "";
        ulong hw = 0;
        if(!RebuildStates(events, states, violation, hw))
            return EINSPECT_CORRUPT;

        double eps = 0.0001;   // ~10 points of price tolerance for "near" (conservative)
        bool near = false;
        for(int i = 0; i < ArraySize(states); i++)
        {
            if(!states[i].brokerVisible)
                continue;
            PlanIdentity prior;
            ParseIntentPlanIdentity(FindIntentPayload(events, states[i].executionId), prior);
            string v = ComparePlanIdentity(cur, prior, eps);
            if(v == EINSPECT_MATCHED)
                return EINSPECT_MATCHED;
            if(v == EINSPECT_AMBIGUOUS)
                near = true;
        }
        if(near)
            return EINSPECT_AMBIGUOUS;
        return EINSPECT_NOT_FOUND;
    }
};

#endif
