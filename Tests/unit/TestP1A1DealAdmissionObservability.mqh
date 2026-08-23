//+------------------------------------------------------------------+
//|              TestP1A1DealAdmissionObservability.mqh               |
//|                                      Copyright 2026, SuperCents_X|
//|          Execution Ledger Integrity - P1-A.1 observability        |
//+------------------------------------------------------------------+
//  P1-A forensics proved that every DEAL_ADD admission refusal - plus the
//  discarded RecordDealByDecisionId result - left the SAME observable:
//  nothing.  A possible lost fill (HISTORY_UNAVAILABLE) was therefore
//  indistinguishable from correct, expected, high-frequency behaviour
//  (NOT_ENTRY on every close; NO_DECISION_TOKEN on every third-party deal),
//  and an orphan attribution vanished entirely.
//
//  P1-A.1 names the four causes.  These tests assert the CLASSIFICATION
//  decision, which is where the defect lived; they deliberately do not
//  assert that a log line reaches the terminal - the same unit/regression
//  safety boundary accepted for P0/F5.
//
//    C-phase  exhaustive ClassifyDealAdmission truth table
//             (selected x 5 entry types x token) + label distinctness
//    R-phase  P0 LedgerAdmitsDealAsEntry non-regression: the admission
//             authority is UNCHANGED and is not affected by the labels
//    O-phase  ClassifyDealAttribution / DealAdmissionRequiresDisclosure -
//             a failed RecordDealByDecisionId is an observable orphan
//
//  No live OrderSend, no broker mutation.  File-core tests use FILE_COMMON
//  paths under Execution\ and clean up after themselves.
//+------------------------------------------------------------------+
#ifndef __TEST_P1A1_DEAL_ADMISSION_OBSERVABILITY_MQH__
#define __TEST_P1A1_DEAL_ADMISSION_OBSERVABILITY_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/CExecutionRecovery.mqh"
#include "../../Trading/CExecutionLedgerWriter.mqh"

//--- count DEAL_IN events for an executionId in the durable ledger.
int P1A1CountDealIn(const string path, const string executionId)
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

//--- move a fresh INTENT to a broker-visible state, as the send path does.
void P1A1MarkSubmitted(CExecutionLedgerWriter &w, const string executionId)
{
    ExecutionTruthRecord t;
    t.retcode = TRADE_RETCODE_DONE;
    t.outcome = EXEC_OUTCOME_FILLED;
    t.dealTicket = 0; t.orderTicket = 0; t.requestId = 0; t.retcodeExternal = 0;
    t.bidAtResult = 0; t.askAtResult = 0; t.brokerComment = "";
    w.RecordResult(executionId, t, H6_POLICY_RECORD);
}

//--- C-phase: exhaustive ClassifyDealAdmission truth table -------------------
void TestP1A1ClassifyDealAdmission(TestCounters &counters)
{
    SUITE_BEGIN("P1-A.1/C - ClassifyDealAdmission truth table");

    //--- selected == false: HISTORY_UNAVAILABLE takes absolute precedence,
    //    for EVERY entry value and EITHER token state.  This is the cause
    //    that may represent a genuinely lost broker fill, so it must never
    //    be masked by a later, more benign label.
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, -1, false),
                "C1  unselectable + unread entry + no token");
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, -1, true),
                "C2  unselectable + unread entry + token");
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, DEAL_ENTRY_IN, false),
                "C3  unselectable + IN + no token");
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, DEAL_ENTRY_IN, true),
                "C4  unselectable + IN + token");
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, DEAL_ENTRY_OUT, false),
                "C5  unselectable + OUT + no token");
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, DEAL_ENTRY_OUT, true),
                "C6  unselectable + OUT + token");
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, DEAL_ENTRY_INOUT, false),
                "C7  unselectable + INOUT + no token");
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, DEAL_ENTRY_INOUT, true),
                "C8  unselectable + INOUT + token");
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, DEAL_ENTRY_OUT_BY, false),
                "C9  unselectable + OUT_BY + no token");
    TEST_STR_EQ(DEAL_ADMIT_HISTORY_UNAVAIL, ClassifyDealAdmission(false, DEAL_ENTRY_OUT_BY, true),
                "C10 unselectable + OUT_BY + token");

    //--- selected == true, non-entry: NOT_ENTRY regardless of the token.
    //    This is the CORRECT, expected, high-frequency case - it fires on
    //    every position close, which is exactly why it must be separable
    //    from C1..C10 rather than sharing one silent exit.
    TEST_STR_EQ(DEAL_ADMIT_NOT_ENTRY, ClassifyDealAdmission(true, DEAL_ENTRY_OUT, false),
                "C11 selected + OUT + no token");
    TEST_STR_EQ(DEAL_ADMIT_NOT_ENTRY, ClassifyDealAdmission(true, DEAL_ENTRY_OUT, true),
                "C12 selected + OUT + token (our own close)");
    TEST_STR_EQ(DEAL_ADMIT_NOT_ENTRY, ClassifyDealAdmission(true, DEAL_ENTRY_INOUT, false),
                "C13 selected + INOUT + no token");
    TEST_STR_EQ(DEAL_ADMIT_NOT_ENTRY, ClassifyDealAdmission(true, DEAL_ENTRY_INOUT, true),
                "C14 selected + INOUT + token (reversal)");
    TEST_STR_EQ(DEAL_ADMIT_NOT_ENTRY, ClassifyDealAdmission(true, DEAL_ENTRY_OUT_BY, false),
                "C15 selected + OUT_BY + no token");
    TEST_STR_EQ(DEAL_ADMIT_NOT_ENTRY, ClassifyDealAdmission(true, DEAL_ENTRY_OUT_BY, true),
                "C16 selected + OUT_BY + token (close-by)");
    TEST_STR_EQ(DEAL_ADMIT_NOT_ENTRY, ClassifyDealAdmission(true, -1, false),
                "C17 selected + unread entry + no token");
    TEST_STR_EQ(DEAL_ADMIT_NOT_ENTRY, ClassifyDealAdmission(true, -1, true),
                "C18 selected + unread entry + token");

    //--- selected == true, entry deal: the token decides.
    TEST_STR_EQ(DEAL_ADMIT_NO_DECISION_TOKEN, ClassifyDealAdmission(true, DEAL_ENTRY_IN, false),
                "C19 selected + IN + no token (third-party / manual deal)");
    TEST_STR_EQ(DEAL_ADMIT_ADMIT, ClassifyDealAdmission(true, DEAL_ENTRY_IN, true),
                "C20 selected + IN + token -> ADMIT (the only success path)");

    //--- the whole point of P1-A.1: the four causes are mutually distinct.
    //    If any two labels collapsed, the disclosure would be worthless.
    string lU = ClassifyDealAdmission(false, DEAL_ENTRY_IN, true);
    string lN = ClassifyDealAdmission(true,  DEAL_ENTRY_OUT, true);
    string lT = ClassifyDealAdmission(true,  DEAL_ENTRY_IN, false);
    string lA = ClassifyDealAdmission(true,  DEAL_ENTRY_IN, true);
    TEST_TRUE(lU != lN, "C21 HISTORY_UNAVAILABLE distinct from NOT_ENTRY");
    TEST_TRUE(lU != lT, "C22 HISTORY_UNAVAILABLE distinct from NO_DECISION_TOKEN");
    TEST_TRUE(lU != lA, "C23 HISTORY_UNAVAILABLE distinct from ADMIT");
    TEST_TRUE(lN != lT, "C24 NOT_ENTRY distinct from NO_DECISION_TOKEN");
    TEST_TRUE(lN != lA, "C25 NOT_ENTRY distinct from ADMIT");
    TEST_TRUE(lT != lA, "C26 NO_DECISION_TOKEN distinct from ADMIT");

    //--- the classifier returns ONLY the four authorised labels.
    TEST_TRUE(lU == DEAL_ADMIT_HISTORY_UNAVAIL || lU == DEAL_ADMIT_NOT_ENTRY ||
              lU == DEAL_ADMIT_NO_DECISION_TOKEN || lU == DEAL_ADMIT_ADMIT,
              "C27 label set closed (no fifth outcome)");

    //--- disclosure predicate: ADMIT is quiet, every other cause speaks.
    TEST_FALSE(DealAdmissionRequiresDisclosure(DEAL_ADMIT_ADMIT),
               "C28 ADMIT requires no disclosure (success path stays quiet)");
    TEST_TRUE(DealAdmissionRequiresDisclosure(DEAL_ADMIT_HISTORY_UNAVAIL),
              "C29 HISTORY_UNAVAILABLE discloses");
    TEST_TRUE(DealAdmissionRequiresDisclosure(DEAL_ADMIT_NOT_ENTRY),
              "C30 NOT_ENTRY discloses");
    TEST_TRUE(DealAdmissionRequiresDisclosure(DEAL_ADMIT_NO_DECISION_TOKEN),
              "C31 NO_DECISION_TOKEN discloses");

    SUITE_END("P1-A.1/C - ClassifyDealAdmission truth table");
}

//--- R-phase: P0 admission authority non-regression -------------------------
void TestP1A1P0GateNonRegression(TestCounters &counters)
{
    SUITE_BEGIN("P1-A.1/R - P0 LedgerAdmitsDealAsEntry non-regression");

    //--- the full P0/1A truth table, re-asserted verbatim.  P1-A.1 is
    //    observability only: if any of these flip, the P0 commit 6f05ed1
    //    has been regressed and execution integrity is compromised.
    TEST_TRUE(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_IN),
              "R1 entry deal admitted");
    TEST_FALSE(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_OUT),
               "R2 close deal (OUT) refused");
    TEST_FALSE(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_INOUT),
               "R3 reversal deal (INOUT) refused");
    TEST_FALSE(LedgerAdmitsDealAsEntry(true, DEAL_ENTRY_OUT_BY),
               "R4 close-by deal (OUT_BY) refused");
    TEST_FALSE(LedgerAdmitsDealAsEntry(false, DEAL_ENTRY_IN),
               "R5 unselectable history refused (fail closed)");
    TEST_FALSE(LedgerAdmitsDealAsEntry(false, -1),
               "R6 unread entry type refused (fail closed)");
    TEST_FALSE(LedgerAdmitsDealAsEntry(false, DEAL_ENTRY_OUT),
               "R7 unselectable + OUT refused");
    TEST_FALSE(LedgerAdmitsDealAsEntry(true, -1),
               "R8 selected but unread entry refused");

    //--- the gate and the classifier must AGREE on admission: exactly the
    //    ADMIT label may pass the gate.  This is the contract that keeps the
    //    labels observability-only - a label can never widen admission.
    int entries[5] = {DEAL_ENTRY_IN, DEAL_ENTRY_OUT, DEAL_ENTRY_INOUT, DEAL_ENTRY_OUT_BY, -1};
    bool agree = true;
    for(int s = 0; s < 2; s++)
        for(int e = 0; e < 5; e++)
        {
            bool sel = (s == 1);
            // the handler admits iff the gate passes AND a token was found;
            // the classifier says ADMIT under exactly that condition.
            bool gateAdmits = LedgerAdmitsDealAsEntry(sel, entries[e]);
            if((ClassifyDealAdmission(sel, entries[e], true) == DEAL_ADMIT_ADMIT) != gateAdmits)
                agree = false;
        }
    TEST_TRUE(agree, "R9 classifier ADMIT agrees with the P0 gate on all 10 inputs");

    //--- a disclosed label never implies admission.
    TEST_TRUE(DealAdmissionRequiresDisclosure(
                  ClassifyDealAdmission(false, DEAL_ENTRY_IN, true)) &&
              !LedgerAdmitsDealAsEntry(false, DEAL_ENTRY_IN),
              "R10 HISTORY_UNAVAILABLE discloses AND stays refused");

    SUITE_END("P1-A.1/R - P0 LedgerAdmitsDealAsEntry non-regression");
}

//--- O-phase: orphan attribution is observable ------------------------------
void TestP1A1OrphanAttribution(TestCounters &counters)
{
    SUITE_BEGIN("P1-A.1/O - orphan attribution observability");

    //--- pure decision surface.
    TEST_STR_EQ(DEAL_ADMIT_ADMIT, ClassifyDealAttribution(true),
                "O1 accepted attribution -> ADMIT");
    TEST_STR_EQ(DEAL_ADMIT_NO_DECISION_TOKEN, ClassifyDealAttribution(false),
                "O2 refused attribution -> NO_DECISION_TOKEN (orphan)");
    TEST_FALSE(DealAdmissionRequiresDisclosure(ClassifyDealAttribution(true)),
               "O3 accepted attribution stays quiet");
    TEST_TRUE(DealAdmissionRequiresDisclosure(ClassifyDealAttribution(false)),
              "O4 orphan attribution discloses (was silently discarded)");

    //--- end to end against the real writer.
    string path    = "Execution\\TestP1A1_O.dat";
    string seqPath = "Execution\\TestP1A1_O_seq.dat";
    FileDelete(path, FILE_COMMON);
    FileDelete(seqPath, FILE_COMMON);

    CExecutionIdentity id;
    id.Init("RUN-P1A1-O", "test", seqPath);
    CExecutionLedgerWriter w;
    TEST_TRUE(w.Init(path, &id, "RUN-P1A1-O", "test"), "O5 writer init");

    long   decisionId = 5201;
    string eid = "";
    TEST_TRUE(w.BeginExecution(decisionId, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12,
                               27182819, 1.1, 1, 0, 2, 0, eid), "O6 intent recorded");
    P1A1MarkSubmitted(w, eid);

    //--- an admitted entry deal for a decisionId with NO execution at all:
    //    the writer refuses (it never fabricates) and the handler previously
    //    discarded that refusal.
    bool orphanUnknown = w.RecordDealByDecisionId(9999, 8801, 0, 0, 1.1, 1.0,
                                                 D'2026.01.01', 0);
    TEST_FALSE(orphanUnknown, "O7 unknown decisionId refused by the writer");
    TEST_STR_EQ(DEAL_ADMIT_NO_DECISION_TOKEN, ClassifyDealAttribution(orphanUnknown),
                "O8 unknown decisionId classified as orphan");
    TEST_INT_EQ(0, P1A1CountDealIn(path, eid),
                "O9 orphan wrote no DEAL_IN record (ledger unchanged)");

    //--- the genuine fill is still accepted and still quiet.
    bool accepted = w.RecordDealByDecisionId(decisionId, 8802, 0, 0, 1.1, 1.0,
                                             D'2026.01.01', 0);
    TEST_TRUE(accepted, "O10 matching non-terminal execution accepted");
    TEST_STR_EQ(DEAL_ADMIT_ADMIT, ClassifyDealAttribution(accepted),
                "O11 accepted fill classified ADMIT");
    TEST_FALSE(DealAdmissionRequiresDisclosure(ClassifyDealAttribution(accepted)),
               "O12 accepted fill produces no diagnostic noise");
    TEST_INT_EQ(1, P1A1CountDealIn(path, eid), "O13 accepted fill wrote one DEAL_IN");

    //--- that execution is now FILLED (terminal).  A further deal carrying the
    //    same decisionId has no non-terminal execution to attach to - the
    //    realistic orphan case, previously invisible.
    bool orphanTerminal = w.RecordDealByDecisionId(decisionId, 8803, 0, 0, 1.1, 1.0,
                                                  D'2026.01.01', 0);
    TEST_FALSE(orphanTerminal, "O14 terminal execution refuses a further deal");
    TEST_STR_EQ(DEAL_ADMIT_NO_DECISION_TOKEN, ClassifyDealAttribution(orphanTerminal),
                "O15 post-terminal deal classified as orphan");
    TEST_TRUE(DealAdmissionRequiresDisclosure(ClassifyDealAttribution(orphanTerminal)),
              "O16 post-terminal orphan discloses");
    TEST_INT_EQ(1, P1A1CountDealIn(path, eid),
                "O17 post-terminal orphan wrote no DEAL_IN (still exactly one)");

    //--- the ledger must still replay cleanly: observability changed nothing
    //    about what was written.
    ExecutionLedgerEvent evs[];
    string info = "";
    TEST_INT_EQ(LEDGER_SCAN_CLEAN, LedgerScan(path, evs, info), "O18 ledger scans clean");
    ExecutionReconState states[];
    string violation = "";
    ulong hw = 0;
    TEST_TRUE(RebuildStates(evs, states, violation, hw), "O19 ledger replays without violation");
    TEST_INT_EQ(1, ArraySize(states), "O20 exactly one execution state (no fabrication)");

    FileDelete(path, FILE_COMMON);
    FileDelete(seqPath, FILE_COMMON);

    SUITE_END("P1-A.1/O - orphan attribution observability");
}

TestCounters RunP1A1DealAdmissionObservabilityTests(void)
{
    TestCounters counters;
    TestP1A1ClassifyDealAdmission(counters);
    TestP1A1P0GateNonRegression(counters);
    TestP1A1OrphanAttribution(counters);
    return counters;
}

#endif // __TEST_P1A1_DEAL_ADMISSION_OBSERVABILITY_MQH__
