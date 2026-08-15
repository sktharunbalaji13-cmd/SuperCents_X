//+------------------------------------------------------------------+
//|                          TestExecutionLedger.mqh                  |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03C-A |
//+------------------------------------------------------------------+
//  B25-03C-A - Execution Ledger Core acceptance tests (T1-T10).
//
//  Pure unit tests + isolated file-core tests of
//  Trading/ExecutionLedger.mqh: versioned header, | -delimited
//  append-only event format, SHA-256 integrity, append + flush,
//  replay reader, eventSeq derivation from the last valid tail,
//  torn-tail detection/recovery, mid-file corruption -> BLOCK,
//  schema/version validation, executionSeq-gap acceptance.
//
//  NO OrderSend wiring, no recovery integration, no reconciliation,
//  no broker inspection, no OnTradeTransaction, no #<seq> wiring.
//
//  TDD contract: this file is written ONCE and stays byte-identical
//  across the RED (defect-mirror) and GREEN (truthful) phases. The
//  RED phase must fail exactly where a naive ledger core is wrong:
//    D1 - header magic/schema/checksum never validated
//    D2 - record checksums never verified (tampered payload accepted)
//    D3 - eventSeq derived from a resetting counter, not the tail
//        (reopen -> duplicate eventSeq)
//    D4 - torn tail silently ignored (scan reports CLEAN)
//    D5 - mid-file corruption silently skipped (scan reports CLEAN)
//    D6 - eventSeq holes/duplicates accepted (no SEQ_VIOLATION)
//    D7 - legal executionSeq gaps rejected / sequence mis-parsed
//    D8 - recovery is a no-op (no truncation, no CORRUPTION record)
//
//  Adversarial gate cases (senior directive) covered here:
//    A  executionSeq gap accepted (reserve-before-use semantics)
//    B  two executions -> distinct executionIds
//    C  one execution, 5 events -> 5 unique eventSeq values
//    D  reopen+append -> no duplicate eventSeq
//    G  duplicate DEAL_IN events round-trip faithfully (dedup itself
//       is B25-03C-C state-machine scope; the ledger must preserve
//       both records byte-identically)
//    H  mid-file corruption -> BLOCK (MID_FILE_CORRUPT)
//    I  torn final record -> RECOVERABLE per Phase 10 rule
//+------------------------------------------------------------------+
#ifndef __TEST_EXECUTION_LEDGER_MQH__
#define __TEST_EXECUTION_LEDGER_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/ExecutionLedger.mqh"

//--- test-only raw append (injects crafted lines that the API would
//    never produce: violations, torn tails, tampered records).
bool TestLedgerRawAppend(const string path, const string line)
{
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(h == INVALID_HANDLE)
        return false;
    FileSeek(h, 0, SEEK_END);
    FileWriteString(h, line + "\r\n");
    FileFlush(h);
    FileClose(h);
    return true;
}

//--- test-only raw overwrite of the FIRST line (header tampering).
bool TestLedgerRawOverwriteFirstLine(const string path, const string newFirstLine)
{
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(h == INVALID_HANDLE)
        return false;
    FileSeek(h, 0, SEEK_SET);
    FileWriteString(h, newFirstLine + "\r\n");
    FileFlush(h);
    FileClose(h);
    return true;
}

void TestLedgerCleanup(const string path)
{
    if(FileIsExist(path, FILE_COMMON))
        FileDelete(path, FILE_COMMON);
}

TestCounters RunExecutionLedgerTests(void)
{
    TestCounters counters;
    SUITE_BEGIN("ExecutionLedger");

    const string R1 = "RUN-CORE-TEST-1";
    const string H1 = "SCX-BUY-P5";
    const string P_INTENT  = "501|EURUSD|BUY|1.10500|0.10|1.10000|1.11000|42|RUN-CORE-TEST-1";
    const string P_DEALIN  = "900001|900011|800001|1.10520|0.10|2026.01.02 10:30:00|0";
    const datetime T0 = D'2026.01.02 10:30:00';

    //================================================================
    // T1. Header: magic, schema version, checksum, malformation.
    //================================================================
    {
        string hdr = LedgerBuildHeader(R1, "build-x", "deadbeef", "6104", T0);
        string err = "";

        TEST_TRUE(LedgerValidateHeader(hdr, err), "T1a: freshly built header validates");
        TEST_STR_EQ("", err, "T1b: validation error empty on success");

        string badMagic = "LEDGERX|1|" + R1 + "|build-x|deadbeef|6104|2026.01.02 10:30:00|" + LedgerChecksumHex("LEDGERX|1|" + R1 + "|build-x|deadbeef|6104|2026.01.02 10:30:00");
        TEST_FALSE(LedgerValidateHeader(badMagic, err), "T1c: wrong magic rejected (D1)");

        string v2 = "LEDGER|2|" + R1 + "|build-x|deadbeef|6104|2026.01.02 10:30:00|" + LedgerChecksumHex("LEDGER|2|" + R1 + "|build-x|deadbeef|6104|2026.01.02 10:30:00");
        TEST_FALSE(LedgerValidateHeader(v2, err), "T1d: unknown schema version rejected (D1)");

        string tamperedHdr = "LEDGER|1|" + R1 + "|build-x|deadbeef|6104|2026.01.02 10:30:00|" + LedgerChecksumHex("LEDGER|1|" + R1 + "|build-x|deadbeef|6104|2026.01.02 09:00:00");
        TEST_FALSE(LedgerValidateHeader(tamperedHdr, err), "T1e: tampered header checksum rejected (D1)");

        TEST_FALSE(LedgerValidateHeader("LEDGER|1|RUN", err), "T1f: malformed header (short) rejected (D1)");
        TEST_FALSE(LedgerValidateHeader("", err), "T1g: empty header rejected");
    }

    //================================================================
    // T2. SHA-256 checksum: determinism and distinctness.
    //================================================================
    {
        string h1 = LedgerChecksumHex("alpha-payload");
        string h2 = LedgerChecksumHex("alpha-payload");
        string h3 = LedgerChecksumHex("beta-payload");

        TEST_STR_EQ(h1, h2, "T2a: same payload -> same checksum (deterministic)");
        TEST_FALSE(h1 == h3, "T2b: distinct payloads -> distinct checksums (D2)");
        TEST_INT_EQ(64, StringLen(h1), "T2c: SHA-256 hex is 64 chars");
        TEST_TRUE(LedgerChecksumMatches("alpha-payload", h1), "T2d: recomputed checksum matches recorded");
        TEST_FALSE(LedgerChecksumMatches("alpha-payload", h3), "T2e: mismatched payload does not match recorded (D2)");
        TEST_FALSE(LedgerChecksumMatches("alpha-payload", "0000"), "T2f: short/stub checksum never matches (D2)");
    }

    //================================================================
    // T3. Record build/parse round-trip and integrity.
    //================================================================
    {
        ExecutionLedgerEvent ev;
        string err = "";
        string line = LedgerBuildRecord(1, "EX-RUN-101", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT);

        TEST_TRUE(LedgerParseRecord(line, ev, err), "T3a: built record parses");
        TEST_INT_EQ(1, (int)ev.eventSeq, "T3b: eventSeq round-trips");
        TEST_STR_EQ("EX-RUN-101", ev.executionId, "T3c: executionId round-trips");
        TEST_STR_EQ("INTENT", ev.eventType, "T3d: eventType round-trips");
        TEST_DATETIME_EQ(T0, ev.timestamp, "T3e: timestamp round-trips");
        TEST_STR_EQ("INTENT", ev.stateFrom, "T3f: stateFrom round-trips");
        TEST_STR_EQ("SUBMITTED", ev.stateTo, "T3g: stateTo round-trips");
        TEST_STR_EQ(P_INTENT, ev.payload, "T3h: payload round-trips byte-identical");
        TEST_STR_EQ(StringSubstr(line, StringLen(line) - 64), LedgerChecksumHex(StringSubstr(line, 0, StringLen(line) - 65)), "T3i: recorded checksum equals recomputed over record body");

        string tampered = StringSubstr(line, 0, StringLen(line) - 70) + "DEADBEEF";
        TEST_FALSE(LedgerParseRecord(tampered, ev, err), "T3j: tampered record rejected (D2)");

        string unknownType = LedgerBuildRecord(2, "EX-RUN-101", "NOT_A_TYPE", T0, "SUBMITTED", "FILLED", "x");
        TEST_FALSE(LedgerParseRecord(unknownType, ev, err), "T3k: unknown eventType rejected");

        TEST_FALSE(LedgerParseRecord("EVT|1|EX-RUN-101", ev, err), "T3l: malformed record (short) rejected");
        TEST_FALSE(LedgerParseRecord("", ev, err), "T3m: empty record rejected");
    }

    //================================================================
    // T4. eventSeq derivation from last valid tail (adversarial D).
    //================================================================
    {
        string path = "Execution\\TestLedger_T4.dat";
        TestLedgerCleanup(path);

        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T4a: create ledger");
        ulong seq = 0;
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT, seq), "T4b: append INTENT");
        TEST_INT_EQ(1, (int)seq, "T4c: first event eventSeq == 1");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "SENT", T0, "SUBMITTED", "ACCEPTED", "77|10012|0|900011|SCX-BUY-P5", seq), "T4d: append SENT");
        TEST_INT_EQ(2, (int)seq, "T4e: second event eventSeq == 2");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "DEAL_IN", T0, "ACCEPTED", "PARTIALLY_FILLED", P_DEALIN, seq), "T4f: append DEAL_IN");
        TEST_INT_EQ(3, (int)seq, "T4g: third event eventSeq == 3");

        ulong tail = 0;
        TEST_TRUE(LedgerTailEventSeq(path, tail), "T4h: tail readable");
        TEST_INT_EQ(3, (int)tail, "T4i: tail == 3 after three appends");

        //--- reopen: derivation must come from the file tail, not memory
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T4j: reopen ledger");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "RECONCILED", T0, "ACCEPTED", "RESOLVED", "RESOLVED|900011", seq), "T4k: append after reopen");
        TEST_INT_EQ(4, (int)seq, "T4l: eventSeq continues at tail+1 after reopen (D3)");

        //--- "crash before append": reopen, read tail, do NOT append, reopen again
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T4m: reopen without appending");
        TEST_TRUE(LedgerTailEventSeq(path, tail), "T4n: tail after empty session");
        TEST_INT_EQ(4, (int)tail, "T4o: tail unchanged by empty session");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-102", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT, seq), "T4p: append after empty session");
        TEST_INT_EQ(5, (int)seq, "T4q: no duplicate eventSeq after empty session (D3)");

        ExecutionLedgerEvent evs[];
        string info = "";
        ENUM_LEDGER_SCAN_RESULT sc = LedgerScan(path, evs, info);
        TEST_INT_EQ((int)LEDGER_SCAN_CLEAN, (int)sc, "T4r: scan clean");
        TEST_INT_EQ(5, ArraySize(evs), "T4s: five events replayed");
        for(int i = 0; i < 5; i++)
        {
            TEST_INT_EQ(i + 1, (int)evs[i].eventSeq, "T4t: eventSeq strictly 1..5 after reopen+append");
        }

        TestLedgerCleanup(path);
    }

    //================================================================
    // T5. Adversarial B + C: executions, executionIds, 5-event run.
    //================================================================
    {
        string path = "Execution\\TestLedger_T5.dat";
        TestLedgerCleanup(path);
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T5a: create ledger");

        ulong seq = 0;
        //--- execution EX-RUN-101: INTENT, SENT, DEAL_IN, DEAL_IN, RECONCILED
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT, seq), "T5b: ex1 INTENT");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "SENT", T0, "SUBMITTED", "ACCEPTED", "77|10012|0|900011|SCX-BUY-P5", seq), "T5c: ex1 SENT");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "DEAL_IN", T0, "ACCEPTED", "PARTIALLY_FILLED", P_DEALIN, seq), "T5d: ex1 DEAL_IN");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "DEAL_IN", T0, "PARTIALLY_FILLED", "FILLED", "900002|900011|800001|1.10522|0.06|2026.01.02 10:31:00|0", seq), "T5e: ex1 DEAL_IN #2");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "RECONCILED", T0, "FILLED", "RESOLVED", "RESOLVED|900002", seq), "T5f: ex1 RECONCILED");
        //--- execution EX-RUN-102 (adversarial B: distinct executionId)
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-102", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT, seq), "T5g: ex2 INTENT");

        ExecutionLedgerEvent evs[];
        string info = "";
        TEST_INT_EQ((int)LEDGER_SCAN_CLEAN, (int)LedgerScan(path, evs, info), "T5h: scan clean");
        TEST_INT_EQ(6, ArraySize(evs), "T5i: six events replayed");

        int ex1Count = 0, ex2Count = 0, seqUnique = 1;
        for(int i = 0; i < ArraySize(evs); i++)
        {
            if(evs[i].executionId == "EX-RUN-101") ex1Count++;
            if(evs[i].executionId == "EX-RUN-102") ex2Count++;
            if(i > 0 && evs[i].eventSeq == evs[i - 1].eventSeq) seqUnique = 0;
            if(i > 0 && evs[i].eventSeq != evs[i - 1].eventSeq + 1) seqUnique = 0;
        }
        TEST_INT_EQ(5, ex1Count, "T5j: adversarial C - one execution produced 5 events");
        TEST_INT_EQ(1, ex2Count, "T5k: adversarial B - second execution distinct");
        TEST_INT_EQ(1, seqUnique, "T5l: adversarial C - 5 unique contiguous eventSeq values");

        TestLedgerCleanup(path);
    }

    //================================================================
    // T6. Torn tail (adversarial I): detect, recover, resume.
    //================================================================
    {
        string path = "Execution\\TestLedger_T6.dat";
        TestLedgerCleanup(path);
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T6a: create ledger");

        ulong seq = 0;
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT, seq), "T6b: append INTENT");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "SENT", T0, "SUBMITTED", "ACCEPTED", "77|10012|0|900011|SCX-BUY-P5", seq), "T6c: append SENT");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "DEAL_IN", T0, "ACCEPTED", "PARTIALLY_FILLED", P_DEALIN, seq), "T6d: append DEAL_IN");

        //--- inject a torn final record: write interrupted mid-payload,
        //    trailing fields + checksum never landed
        string body = StringFormat("EVT|4|EX-RUN-101|DEAL_IN|%s|PARTIALLY_FILLED|FILLED|900001", TimeToString(T0));
        TEST_TRUE(TestLedgerRawAppend(path, body), "T6e: inject torn tail");

        ExecutionLedgerEvent evs[];
        string info = "";
        ENUM_LEDGER_SCAN_RESULT sc = LedgerScan(path, evs, info);
        TEST_INT_EQ((int)LEDGER_SCAN_TORN_TAIL, (int)sc, "T6f: torn tail classified TORN_TAIL, not CLEAN (D4)");
        TEST_INT_EQ(3, ArraySize(evs), "T6g: valid records before the torn tail replayed");

        TEST_TRUE(LedgerRecoverTornTail(path, info), "T6h: recovery succeeds (D8)");
        sc = LedgerScan(path, evs, info);
        TEST_INT_EQ((int)LEDGER_SCAN_CLEAN, (int)sc, "T6i: scan clean after recovery (D8)");
        int corrCount = 0;
        int n = ArraySize(evs);
        for(int i = 0; i < n; i++)
        {
            if(evs[i].eventType == "CORRUPTION") corrCount++;
        }
        TEST_INT_EQ(1, corrCount, "T6j: CORRUPTION record appended - evidence not silently discarded (D8)");
        TEST_INT_EQ(4, n, "T6k: 3 records + CORRUPTION record replayed");
        TEST_INT_EQ(4, (int)evs[n - 1].eventSeq, "T6l: CORRUPTION record continues contiguously at tail+1");

        //--- append after recovery: next eventSeq continues contiguously
        ulong next = 0;
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "RECONCILED", T0, "FILLED", "RESOLVED", "RESOLVED|900002", next), "T6m: append after recovery");
        TEST_INT_EQ(5, (int)next, "T6n: eventSeq resumes at 5 after recovery");

        TestLedgerCleanup(path);
    }

    //================================================================
    // T7. Mid-file corruption (adversarial H): BLOCK, never skip.
    //================================================================
    {
        string path = "Execution\\TestLedger_T7.dat";
        TestLedgerCleanup(path);
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T7a: create ledger");

        ulong seq = 0;
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT, seq), "T7b: append INTENT");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "SENT", T0, "SUBMITTED", "ACCEPTED", "77|10012|0|900011|SCX-BUY-P5", seq), "T7c: append SENT");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "DEAL_IN", T0, "ACCEPTED", "PARTIALLY_FILLED", P_DEALIN, seq), "T7d: append DEAL_IN");

        //--- inject a mid-file corrupted record: valid shape, tampered payload, stale checksum
        string good = LedgerBuildRecord(2, "EX-RUN-101", "SENT", T0, "SUBMITTED", "ACCEPTED", "77|10012|0|900011|SCX-BUY-P5");
        string corrupted = StringSubstr(good, 0, StringLen(good) - 70) + "9999999999999999999999999999999999999999999999999999999999999999";
        TEST_TRUE(TestLedgerRawAppend(path, "TAMPERED|" + corrupted), "T7e: inject malformed mid-file line");

        ExecutionLedgerEvent evs[];
        string info = "";
        ENUM_LEDGER_SCAN_RESULT sc = LedgerScan(path, evs, info);
        TEST_INT_EQ((int)LEDGER_SCAN_MID_FILE_CORRUPT, (int)sc, "T7f: malformed mid-file line -> MID_FILE_CORRUPT (D5)");

        //--- tampered-but-well-formed mid-file record (bad checksum)
        TestLedgerCleanup(path);
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T7g: recreate ledger");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT, seq), "T7h: append INTENT");
        string tampered = StringSubstr(good, 0, StringLen(good) - 70) + "DEADBEEF";
        TEST_TRUE(TestLedgerRawAppend(path, tampered), "T7i: inject checksum-failed mid-file record");
        TEST_TRUE(TestLedgerRawAppend(path, LedgerBuildRecord(3, "EX-RUN-101", "DEAL_IN", T0, "ACCEPTED", "PARTIALLY_FILLED", P_DEALIN)), "T7j: append valid record after corrupted one");

        sc = LedgerScan(path, evs, info);
        TEST_INT_EQ((int)LEDGER_SCAN_MID_FILE_CORRUPT, (int)sc, "T7k: checksum-failed mid-file record -> MID_FILE_CORRUPT (D5)");
        TEST_INT_EQ(1, ArraySize(evs), "T7l: replay stops at corruption; nothing after it is trusted");

        //--- recovery must refuse mid-file corruption (Phase 10: BLOCK)
        TEST_FALSE(LedgerRecoverTornTail(path, info), "T7m: recovery refuses mid-file corruption (BLOCK)");

        TestLedgerCleanup(path);
    }

    //================================================================
    // T8. eventSeq violations: holes and duplicates -> SEQ_VIOLATION.
    //================================================================
    {
        string path = "Execution\\TestLedger_T8.dat";
        TestLedgerCleanup(path);
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T8a: create ledger");

        TEST_TRUE(TestLedgerRawAppend(path, LedgerBuildRecord(1, "EX-RUN-101", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT)), "T8b: append seq 1");
        TEST_TRUE(TestLedgerRawAppend(path, LedgerBuildRecord(2, "EX-RUN-101", "SENT", T0, "SUBMITTED", "ACCEPTED", "x")), "T8c: append seq 2");
        TEST_TRUE(TestLedgerRawAppend(path, LedgerBuildRecord(4, "EX-RUN-101", "DEAL_IN", T0, "ACCEPTED", "PARTIALLY_FILLED", P_DEALIN)), "T8d: append seq 4 (hole at 3)");

        ExecutionLedgerEvent evs[];
        string info = "";
        TEST_INT_EQ((int)LEDGER_SCAN_SEQ_VIOLATION, (int)LedgerScan(path, evs, info), "T8e: eventSeq hole -> SEQ_VIOLATION (D6)");

        TestLedgerCleanup(path);
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T8f: recreate ledger");
        TEST_TRUE(TestLedgerRawAppend(path, LedgerBuildRecord(1, "EX-RUN-101", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT)), "T8g: append seq 1");
        TEST_TRUE(TestLedgerRawAppend(path, LedgerBuildRecord(1, "EX-RUN-102", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT)), "T8h: append seq 1 again");

        TEST_INT_EQ((int)LEDGER_SCAN_SEQ_VIOLATION, (int)LedgerScan(path, evs, info), "T8i: duplicate eventSeq -> SEQ_VIOLATION (D6)");

        TestLedgerCleanup(path);
    }

    //================================================================
    // T9. executionSeq gap acceptance (adversarial A) + parsing.
    //================================================================
    {
        TEST_INT_EQ(101, (int)LedgerExtractExecutionSeq("EX-RUN-101"), "T9a: executionSeq parsed from executionId");
        TEST_INT_EQ(103, (int)LedgerExtractExecutionSeq("EX-RUN-103"), "T9b: two-digit-and-up executionSeq parsed (D7)");
        TEST_INT_EQ(0, (int)LedgerExtractExecutionSeq("NOT-AN-ID"), "T9c: malformed executionId -> 0");

        string path = "Execution\\TestLedger_T9.dat";
        TestLedgerCleanup(path);
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T9d: create ledger");

        //--- executionSeq 101 and 103; 102 was reserved then crashed before INTENT (legal gap)
        ulong seq = 0;
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT, seq), "T9e: INTENT executionSeq 101");
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-103", "INTENT", T0, "INTENT", "SUBMITTED", P_INTENT, seq), "T9f: INTENT executionSeq 103");

        ExecutionLedgerEvent evs[];
        string info = "";
        TEST_INT_EQ((int)LEDGER_SCAN_CLEAN, (int)LedgerScan(path, evs, info), "T9g: scan clean - executionSeq gap is legal (D7)");

        ulong floor = 0;
        TEST_TRUE(LedgerHighWaterExecutionSeq(evs, ArraySize(evs), floor), "T9h: high-water computed over INTENTs");
        TEST_INT_EQ(103, (int)floor, "T9i: high-water == max executionSeq, gap tolerated (D7)");

        TestLedgerCleanup(path);
    }

    //================================================================
    // T10. All event types round-trip; header corruption blocks.
    //================================================================
    {
        string path = "Execution\\TestLedger_T10.dat";
        TestLedgerCleanup(path);
        TEST_TRUE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T10a: create ledger");

        string types[] = { "INTENT", "SENT", "REJECTED", "UNKNOWN", "DEAL_IN", "RECONCILED", "BLOCKED", "RUN_END" };
        string payloads[] = { P_INTENT, "77|10012|0|900011|SCX-BUY-P5", "10006|0|No money", "10012|0|1.10510|1.10530|timed out", P_DEALIN, "RESOLVED|900002", "ambiguity blocks execution", "final" };
        ulong seq = 0;
        for(int i = 0; i < 8; i++)
        {
            TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", types[i], T0, "s", "t", payloads[i], seq), "T10b: append " + types[i]);
            TEST_INT_EQ(i + 1, (int)seq, "T10c: eventSeq 1..8 sequential");
        }

        ExecutionLedgerEvent evs[];
        string info = "";
        TEST_INT_EQ((int)LEDGER_SCAN_CLEAN, (int)LedgerScan(path, evs, info), "T10d: scan clean");
        TEST_INT_EQ(8, ArraySize(evs), "T10e: eight events replayed");
        for(int i = 0; i < 8; i++)
        {
            TEST_STR_EQ(types[i], evs[i].eventType, "T10f: type round-trips");
            TEST_STR_EQ(payloads[i], evs[i].payload, "T10g: payload round-trips byte-identical");
            TEST_STR_EQ("EX-RUN-101", evs[i].executionId, "T10h: executionId preserved");
        }
        //--- adversarial G: duplicate DEAL_IN records preserved faithfully (dedup is B25-03C-C scope)
        TEST_TRUE(LedgerAppendEvent(path, "EX-RUN-101", "DEAL_IN", T0, "PARTIALLY_FILLED", "FILLED", P_DEALIN, seq), "T10i: append duplicate DEAL_IN ticket");
        TEST_INT_EQ(9, (int)seq, "T10j: duplicate DEAL_IN appended with its own eventSeq");
        TEST_INT_EQ((int)LEDGER_SCAN_CLEAN, (int)LedgerScan(path, evs, info), "T10k: scan still clean with duplicate DEAL_IN");
        TEST_INT_EQ(9, ArraySize(evs), "T10l: nine events - both DEAL_IN records preserved");
        TEST_STR_EQ(P_DEALIN, evs[8].payload, "T10m: duplicate DEAL_IN payload intact");

        //--- header corruption on reopen -> refuse (BLOCK)
        string badHdr = "LEDGER|9|" + R1 + "|build-x|deadbeef|6104|2026.01.02 10:30:00|" + LedgerChecksumHex("LEDGER|9|" + R1 + "|build-x|deadbeef|6104|2026.01.02 10:30:00");
        TEST_TRUE(TestLedgerRawOverwriteFirstLine(path, badHdr), "T10n: tamper header in place");
        TEST_FALSE(LedgerOpenOrCreate(path, R1, "build-x", "deadbeef", "6104"), "T10o: reopened ledger with corrupted header refused (D1)");

        TestLedgerCleanup(path);
    }

    SUITE_END("ExecutionLedger");
    return counters;
}

#endif
