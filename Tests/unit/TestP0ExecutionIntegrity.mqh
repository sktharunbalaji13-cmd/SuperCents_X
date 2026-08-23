//+------------------------------------------------------------------+
//|                     TestP0ExecutionIntegrity.mqh                  |
//|                                      Copyright 2026, SuperCents_X|
//|                     Execution Ledger Integrity - P0 remediation   |
//+------------------------------------------------------------------+
//  Targeted regression tests for the three proven P0 fail-open modes.
//  Each phase is a RED gate: it fails against the pre-fix behaviour and
//  passes with the fix.
//
//    P0/1A  OnTradeTransaction admitted ANY deal carrying the entry
//           comment, so a close deal (OUT / INOUT / OUT_BY) could be
//           folded into filledVolume as if it were another fill.
//    P0/1B  CExecutionLedgerWriter::RecordDeal did not enforce
//           Invariant 8 (filledVolume <= requestedVolume + 1e-8) even
//           though RebuildStates REFUSES a ledger that violates it -
//           an over-fill append produced an unreadable, unrepairable
//           append-only ledger (writer Init false, recovery BLOCKED).
//    P0/F5  ENTRY_MODE_LEGACY wired the ledger modules OUTSIDE the
//           init-success branches, so a failed ledger init left every
//           module NULL while execution stayed ENABLED - live OrderSend
//           with no durable INTENT, no duplicate defense, no block gate.
//
//  No live OrderSend, no broker mutation.  File-core tests use
//  FILE_COMMON paths under Execution\ and clean up after themselves.
//+------------------------------------------------------------------+
#ifndef __TEST_P0_EXECUTION_INTEGRITY_MQH__
#define __TEST_P0_EXECUTION_INTEGRITY_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/CExecutionRecovery.mqh"
#include "../../Trading/CExecutionLedgerWriter.mqh"
#include "../../Trading/TradeManager.mqh"

//--- move a fresh INTENT to a broker-visible state (H6 RECORD), as the
//    live send path does before any DEAL_IN can arrive.
void P0MarkSubmitted(CExecutionLedgerWriter &w, const string executionId)
{
    ExecutionTruthRecord t;
    t.retcode = TRADE_RETCODE_DONE;
    t.outcome = EXEC_OUTCOME_FILLED;
    t.dealTicket = 0; t.orderTicket = 0; t.requestId = 0; t.retcodeExternal = 0;
    t.bidAtResult = 0; t.askAtResult = 0; t.brokerComment = "";
    w.RecordResult(executionId, t, H6_POLICY_RECORD);
}

//--- replay a ledger exactly as the next start would.
bool P0Replay(const string path, ExecutionReconState &states[], string &violation)
{
    ExecutionLedgerEvent evs[];
    string info = "";
    if(LedgerScan(path, evs, info) != LEDGER_SCAN_CLEAN)
    {
        violation = "scan:" + info;
        return false;
    }
    ulong hw = 0;
    return RebuildStates(evs, states, violation, hw);
}

//--- count DEAL_IN events for an executionId in the durable ledger.
int P0CountDealIn(const string path, const string executionId)
{
    ExecutionLedgerEvent evs[];
    string info = "";
    if(LedgerScan(path, evs, info) != LEDGER_SCAN_CLEAN)
        return -1;
    int n = 0;
    for(int i = 0; i < ArraySize(evs); i++)
        if(evs[i].eventType == LEDGER_EVENT_DEAL_IN && evs[i].executionId == executionId)
            n++;
    return n;
}

//--- P0/1A: only an ENTRY deal may become a DEAL_IN record -------------------
void TestP0DealEntryAdmission(TestCounters &counters)
{
    SUITE_BEGIN("P0/1A - DEAL_ENTRY_IN admission gate");

    //--- pure gate: the decision point used by OnTradeTransaction.
    TEST_TRUE(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_IN),
              "A1 entry deal admitted");
    TEST_FALSE(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_OUT),
               "A2 close deal (OUT) refused");
    TEST_FALSE(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_INOUT),
               "A3 reversal deal (INOUT) refused");
    TEST_FALSE(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_OUT_BY),
               "A4 close-by deal (OUT_BY) refused");
    TEST_FALSE(LedgerAdmitsDealAsEntry(false, DEAL_ENTRY_IN),
               "A5 unselectable history refused (fail closed)");
    TEST_FALSE(LedgerAdmitsDealAsEntry(false, -1),
               "A6 unread entry type refused (fail closed)");

    //--- end to end: a non-entry deal must not produce a DEAL_IN record.
    string path    = "Execution\\TestP0_1A.dat";
    string seqPath = "Execution\\TestP0_1A_seq.dat";
    FileDelete(path, FILE_COMMON);
    FileDelete(seqPath, FILE_COMMON);

    CExecutionIdentity id;
    id.Init("RUN-P0-1A", "test", seqPath);
    CExecutionLedgerWriter w;
    TEST_TRUE(w.Init(path, &id, "RUN-P0-1A", "test"), "A7 writer init");

    long   decisionId = 4101;
    string eid = "";
    TEST_TRUE(w.BeginExecution(decisionId, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12,
                               27182819, 1.1, 1, 0, 2, 0, eid), "A8 intent recorded");
    P0MarkSubmitted(w, eid);

    //--- a broker DEAL_ADD for the CLOSE of that position carries the same
    //    "SCX-BUY-P4101" comment.  The gate must stop it before the writer.
    if(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_OUT))
        w.RecordDealByDecisionId(decisionId, 7701, 0, 0, 1.1, 1.0, D'2026.01.01', 0);
    TEST_INT_EQ(0, P0CountDealIn(path, eid), "A9 close deal wrote no DEAL_IN record");

    ExecutionReconState st[];
    string violation = "";
    TEST_TRUE(P0Replay(path, st, violation), "A10 ledger replays clean after close deal");
    int idx = FindStateByExecutionId(st, eid);
    TEST_TRUE(idx >= 0, "A11 execution present after replay");
    if(idx >= 0)
    {
        TEST_DBL_NEAR(0.0, st[idx].filledVolume, 1e-9, "A12 close deal not counted as fill");
        TEST_INT_EQ(0, st[idx].dealCount, "A13 no deal ticket attached");
    }

    //--- the legitimate entry deal for the same decision still records.
    if(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_IN))
        w.RecordDealByDecisionId(decisionId, 7702, 0, 0, 1.1, 1.0, D'2026.01.01', 0);
    TEST_INT_EQ(1, P0CountDealIn(path, eid), "A14 entry deal still recorded");

    ExecutionReconState st2[];
    violation = "";
    TEST_TRUE(P0Replay(path, st2, violation), "A15 ledger replays clean after entry deal");
    int idx2 = FindStateByExecutionId(st2, eid);
    if(idx2 >= 0)
    {
        TEST_DBL_NEAR(1.0, st2[idx2].filledVolume, 1e-9, "A16 entry fill accounted");
        TEST_STR_EQ(EXEC_STATE_FILLED, st2[idx2].state, "A17 execution FILLED");
    }

    FileDelete(path, FILE_COMMON);
    FileDelete(seqPath, FILE_COMMON);

    SUITE_END("P0/1A - DEAL_ENTRY_IN admission gate");
}

//--- P0/1B: Invariant 8 enforced at the writer -------------------------------
//    DISTINCT deal tickets whose volumes cumulatively exceed the requested
//    volume.  Duplicate-ticket tests cannot expose this: Invariant 7
//    idempotency short-circuits before the accumulation.
void TestP0Invariant8AtWriter(TestCounters &counters)
{
    SUITE_BEGIN("P0/1B - Invariant 8 at the ledger writer");

    string path    = "Execution\\TestP0_Inv8.dat";
    string seqPath = "Execution\\TestP0_Inv8_seq.dat";
    FileDelete(path, FILE_COMMON);
    FileDelete(seqPath, FILE_COMMON);

    CExecutionIdentity id;
    id.Init("RUN-P0-INV8", "test", seqPath);
    CExecutionLedgerWriter w;
    TEST_TRUE(w.Init(path, &id, "RUN-P0-INV8", "test"), "B1 writer init");

    string eid = "";
    TEST_TRUE(w.BeginExecution(4201, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12,
                               27182819, 1.1, 1, 0, 2, 0, eid), "B2 intent recorded (requested 1.0)");
    P0MarkSubmitted(w, eid);

    //--- first partial fill: legitimate.
    TEST_TRUE(w.RecordDeal(eid, 9101, 0, 0, 1.1, 0.6, D'2026.01.01', 0),
              "B3 first partial fill 0.6 recorded");

    //--- second DISTINCT ticket that would take the total to 1.2 > 1.0.
    TEST_FALSE(w.RecordDeal(eid, 9102, 0, 0, 1.1, 0.6, D'2026.01.01', 0),
               "B4 over-fill by distinct ticket REFUSED (Invariant 8)");

    //--- the refusal must be side-effect-free: the remaining 0.4 still fills.
    TEST_TRUE(w.RecordDeal(eid, 9103, 0, 0, 1.1, 0.4, D'2026.01.01', 0),
              "B5 remaining 0.4 still records (refusal left state intact)");

    //--- and the ledger must remain readable by the NEXT start.  This is the
    //    unrecoverable half of the defect: an accepted over-fill append makes
    //    RebuildStates refuse the whole append-only file forever.
    ExecutionReconState st[];
    string violation = "";
    TEST_TRUE(P0Replay(path, st, violation), "B6 ledger still replays clean (no unrepairable ledger)");
    TEST_STR_EQ("", violation, "B7 no replay violation");
    int idx = FindStateByExecutionId(st, eid);
    TEST_TRUE(idx >= 0, "B8 execution present after replay");
    if(idx >= 0)
    {
        TEST_DBL_NEAR(1.0, st[idx].filledVolume, 1e-9, "B9 filledVolume capped at requested (1.0)");
        TEST_INT_EQ(2, st[idx].dealCount, "B10 exactly two accepted deal tickets");
        TEST_STR_EQ(EXEC_STATE_FILLED, st[idx].state, "B11 execution FILLED");
    }

    //--- a fresh writer over the same file must initialize (i.e. execution is
    //    not permanently blocked on restart).
    CExecutionIdentity id2;
    id2.Init("RUN-P0-INV8B", "test", seqPath);
    CExecutionLedgerWriter w2;
    TEST_TRUE(w2.Init(path, &id2, "RUN-P0-INV8B", "test"),
              "B12 restart writer init succeeds (ledger not poisoned)");

    //--- rejection boundary: 1e-7 over requested is refused, 1e-9 over is
    //    inside the +1e-8 tolerance and accepted (valid accounting unchanged).
    string eidB = "";
    TEST_TRUE(w2.BeginExecution(4202, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12,
                                27182819, 1.1, 1, 0, 2, 0, eidB), "B13 second intent recorded");
    P0MarkSubmitted(w2, eidB);
    TEST_FALSE(w2.RecordDeal(eidB, 9201, 0, 0, 1.1, 1.0000001, D'2026.01.01', 0),
               "B14 fill 1e-7 above requested REFUSED");
    TEST_TRUE(w2.RecordDeal(eidB, 9202, 0, 0, 1.1, 1.000000001, D'2026.01.01', 0),
              "B15 fill within +1e-8 tolerance still accepted");

    ExecutionReconState st2[];
    violation = "";
    TEST_TRUE(P0Replay(path, st2, violation), "B16 ledger replays clean at the boundary");
    int idxB = FindStateByExecutionId(st2, eidB);
    if(idxB >= 0)
        TEST_STR_EQ(EXEC_STATE_FILLED, st2[idxB].state, "B17 boundary execution FILLED");

    FileDelete(path, FILE_COMMON);
    FileDelete(seqPath, FILE_COMMON);

    SUITE_END("P0/1B - Invariant 8 at the ledger writer");
}

//--- P0/F5: failed ledger init must disable execution -----------------------
void TestP0FailClosedExecutionWiring(TestCounters &counters)
{
    SUITE_BEGIN("P0/F5 - fail-closed execution wiring");

    //--- the wiring gate: LEGACY requires ALL durable modules.
    TEST_TRUE(LedgerWiringPermitsExecution(true, true, true, true),
              "F1 fully wired LEGACY permits execution");
    TEST_FALSE(LedgerWiringPermitsExecution(true, false, true, true),
               "F2 missing ledger writer blocks execution (no durable INTENT)");
    TEST_FALSE(LedgerWiringPermitsExecution(true, true, false, true),
               "F3 missing recovery blocks execution (no block gate)");
    TEST_FALSE(LedgerWiringPermitsExecution(true, true, true, false),
               "F4 missing plan inspection blocks execution (no duplicate defense)");
    TEST_FALSE(LedgerWiringPermitsExecution(true, false, false, false),
               "F5 total ledger-init failure blocks execution");

    //--- dormant modes are unaffected: SHADOW/NEW never create the modules
    //    and never send, so absence there is by design, not a failure.
    TEST_TRUE(LedgerWiringPermitsExecution(false, false, false, false),
              "F6 non-LEGACY dormancy still permitted (no behaviour change)");

    //--- the mechanism the fix uses actually closes the send-path gate.
    CTradeManager manager;
    manager.SetSymbol(_Symbol);
    manager.SetMagicNumber(27182819);
    TEST_TRUE(manager.Init(), "F7 TradeManager init");
    manager.SetExecutionEnabled(true);      // as LEGACY does before wiring
    TEST_TRUE(manager.IsExecutionEnabled(), "F8 LEGACY starts execution-enabled");

    //--- replay the failed-init wiring outcome: every module NULL.
    manager.SetLedgerWriter(NULL);
    manager.SetRecovery(NULL);
    manager.SetPlanInspection(NULL);
    if(!LedgerWiringPermitsExecution(true, false, false, false))
        manager.SetExecutionEnabled(false);
    TEST_FALSE(manager.IsExecutionEnabled(),
               "F9 failed ledger init disables execution before the send path");

    //--- and a successful init must NOT disable it.
    CExecutionRecovery         recovery;
    CExecutionPlanInspection   inspection;
    CExecutionLedgerWriter     okWriter;
    CTradeManager wired;
    wired.SetSymbol(_Symbol);
    wired.SetMagicNumber(27182819);
    TEST_TRUE(wired.Init(), "F10 TradeManager init (wired)");
    wired.SetExecutionEnabled(true);
    wired.SetLedgerWriter(&okWriter);
    wired.SetRecovery(&recovery);
    wired.SetPlanInspection(&inspection);
    if(!LedgerWiringPermitsExecution(true, true, true, true))
        wired.SetExecutionEnabled(false);
    TEST_TRUE(wired.IsExecutionEnabled(),
              "F11 fully wired LEGACY stays execution-enabled (success path unchanged)");

    SUITE_END("P0/F5 - fail-closed execution wiring");
}

TestCounters RunP0ExecutionIntegrityTests(void)
{
    TestCounters counters;
    TestP0DealEntryAdmission(counters);
    TestP0Invariant8AtWriter(counters);
    TestP0FailClosedExecutionWiring(counters);
    return counters;
}

#endif // __TEST_P0_EXECUTION_INTEGRITY_MQH__
