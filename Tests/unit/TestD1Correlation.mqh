//+------------------------------------------------------------------+
//|                        TestD1Correlation.mqh                     |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B D1   |
//+------------------------------------------------------------------+
//  D1 - Restart-Stable Broker Correlation acceptance tests.
//
//  Verifies the #<seq> comment wiring (frozen B25-03A format) into the
//  request builder, and the exact correspondence:
//    AllocateSeq -> BuildExecutionId -> seq == LedgerExtractExecutionSeq
//    SetCorrelationComment -> ParseSeqFromComment -> same seq
//  plus BUY/SELL, worst-case 31-char bound, legacy parser compatibility,
//  restart continuity, malformed/legacy rejection.
//+------------------------------------------------------------------+
#ifndef __TEST_D1_CORRELATION_MQH__
#define __TEST_D1_CORRELATION_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/TradeRequestBuilder.mqh"
#include "../../Trading/ExecutionIdentity.mqh"
#include "../../Trading/ExecutionLedger.mqh"

//--- comment format + round-trip ---------------------------------------------
void TestD1CommentFormat(TestCounters &counters)
{
    SUITE_BEGIN("D1 - comment format + round-trip");

    CTradeRequestBuilder builder;
    MqlTradeRequest req;
    ZeroMemory(req);

    builder.SetCorrelationComment(req, "BUY", 123, 456);
    TEST_STR_EQ("SCX-BUY-P123#456", req.comment, "T1a BUY format");

    builder.SetCorrelationComment(req, "SELL", 123, 456);
    TEST_STR_EQ("SCX-SELL-P123#456", req.comment, "T1b SELL format");

    // idempotent (setting twice yields the same string, no double tail)
    builder.SetCorrelationComment(req, "SELL", 123, 456);
    TEST_STR_EQ("SCX-SELL-P123#456", req.comment, "T1c idempotent");

    SUITE_END("D1 - comment format + round-trip");
}

//--- round-trip through the frozen parsers ------------------------------------
void TestD1RoundTrip(TestCounters &counters)
{
    SUITE_BEGIN("D1 - round-trip through frozen parsers");

    CExecutionIdentity id;
    id.Init("RUN-TESTD1", "test", "Execution\\TestD1_seq.dat");

    CTradeRequestBuilder builder;
    MqlTradeRequest req;
    ZeroMemory(req);
    builder.SetCorrelationComment(req, "BUY", 123, 456);

    long d = 0;
    ulong s = 0;
    TEST_TRUE(id.ParseDecisionId(req.comment, d), "T2a ParseDecisionId ok");
    TEST_TRUE(d == 123, "T2b decisionId 123 (version-agnostic)");
    TEST_TRUE(id.ParseSeqFromComment(req.comment, s), "T2c ParseSeqFromComment ok");
    TEST_TRUE(s == 456, "T2d seq 456");

    SUITE_END("D1 - round-trip through frozen parsers");
}

//--- worst-case length bound (never exceeds 31) -------------------------------
void TestD1MaxLength(TestCounters &counters)
{
    SUITE_BEGIN("D1 - maximum-length boundary");

    CTradeRequestBuilder builder;
    MqlTradeRequest req;
    ZeroMemory(req);
    builder.SetCorrelationComment(req, "SELL", 2147483647, 99999999);
    TEST_STR_EQ("SCX-SELL-P2147483647#99999999", req.comment, "T3a worst-case format");
    TEST_TRUE(StringLen(req.comment) <= 31, "T3b worst-case length <= 31 (got " + IntegerToString(StringLen(req.comment)) + ")");

    builder.SetCorrelationComment(req, "BUY", 2147483647, 99999999);
    TEST_TRUE(StringLen(req.comment) <= 31, "T3c BUY worst-case length <= 31");

    SUITE_END("D1 - maximum-length boundary");
}

//--- sequence <-> executionId correspondence ----------------------------------
void TestD1SequenceCorrespondence(TestCounters &counters)
{
    SUITE_BEGIN("D1 - sequence <-> executionId correspondence");

    CExecutionIdentity id;
    id.Init("RUN-TESTD1", "test", "Execution\\TestD1_seq.dat");

    ulong seq = 0;
    TEST_TRUE(id.AllocateSeq(seq), "T4a allocate seq");
    string eid = "";
    TEST_TRUE(id.BuildExecutionId(seq, eid), "T4b build executionId");
    TEST_TRUE(LedgerExtractExecutionSeq(eid) == seq, "T4c executionId embeds the same seq");

    // the comment carries the SAME seq as the executionId
    CTradeRequestBuilder builder;
    MqlTradeRequest req;
    ZeroMemory(req);
    builder.SetCorrelationComment(req, "BUY", 42, seq);
    ulong s = 0;
    TEST_TRUE(id.ParseSeqFromComment(req.comment, s), "T4d parse seq back");
    TEST_TRUE(s == seq, "T4e comment seq == executionId seq");

    SUITE_END("D1 - sequence <-> executionId correspondence");
}

//--- multiple executions / distinct seqs / restart continuity -----------------
void TestD1UniquenessAndRestart(TestCounters &counters)
{
    SUITE_BEGIN("D1 - uniqueness + restart continuity");

    string counterPath = "Execution\\TestD1_uniq_seq.dat";
    FileDelete(counterPath, FILE_COMMON);

    CExecutionIdentity id;
    TEST_TRUE(id.Init("RUN-TESTD1", "test", counterPath), "T5a init");

    ulong s1 = 0, s2 = 0;
    TEST_TRUE(id.AllocateSeq(s1), "T5b alloc 1");
    TEST_TRUE(id.AllocateSeq(s2), "T5c alloc 2");
    TEST_TRUE(s1 != s2, "T5d distinct seqs (no reuse)");

    // restart continuity: re-Init on the same counter continues monotonically
    CExecutionIdentity id2;
    TEST_TRUE(id2.Init("RUN-TESTD1", "test", counterPath), "T5e re-init (restart)");
    ulong s3 = 0;
    TEST_TRUE(id2.AllocateSeq(s3), "T5f alloc after restart");
    TEST_TRUE(s3 > s2, "T5g restart continues monotonically (no rollback reuse)");

    FileDelete(counterPath, FILE_COMMON);

    SUITE_END("D1 - uniqueness + restart continuity");
}

//--- legacy/malformed comment handling (never inferred) -----------------------
void TestD1LegacyMalformed(TestCounters &counters)
{
    SUITE_BEGIN("D1 - legacy/malformed handling");

    CExecutionIdentity id;
    id.Init("RUN-TESTD1", "test", "Execution\\TestD1_seq.dat");

    // legacy comment (no #<seq>) -> ParseSeqFromComment false
    ulong s = 0;
    TEST_FALSE(id.ParseSeqFromComment("SCX-BUY-P123", s), "T6a legacy has no seq tail");

    // malformed comments -> parsers return false (never inferred)
    long d = 0;
    TEST_FALSE(id.ParseDecisionId("no token here", d), "T6b no -P token -> false");
    TEST_FALSE(id.ParseDecisionId("SCX-BUY-P", d), "T6c empty id -> false");
    TEST_FALSE(id.ParseSeqFromComment("SCX-BUY-P123#", s), "T6d empty seq tail -> false");
    TEST_FALSE(id.ParseSeqFromComment("no hash here", s), "T6e no # -> false");

    // unknown side refused by the frozen builder semantics (BuildComment)
    string c = "";
    TEST_FALSE(id.BuildComment("HEDGE", 123, 456, c), "T6f unknown side refused");

    SUITE_END("D1 - legacy/malformed handling");
}

TestCounters RunD1CorrelationTests(void)
{
    TestCounters counters;
    TestD1CommentFormat(counters);
    TestD1RoundTrip(counters);
    TestD1MaxLength(counters);
    TestD1SequenceCorrespondence(counters);
    TestD1UniquenessAndRestart(counters);
    TestD1LegacyMalformed(counters);
    return counters;
}

#endif // __TEST_D1_CORRELATION_MQH__
