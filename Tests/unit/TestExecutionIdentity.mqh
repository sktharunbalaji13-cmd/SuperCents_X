//+------------------------------------------------------------------+
//|                              TestExecutionIdentity.mqh           |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03A |
//+------------------------------------------------------------------+
//  B25-03A - Canonical Execution Identity acceptance tests.
//
//  Covers the SENIOR acceptance criteria:
//    - identity uniqueness (same intent -> same id; different intent
//      -> different id)
//    - restart/crash safety (sequence cannot roll backward; reserved
//      sequence cannot be reused; corrupt/missing counter fail-safe)
//    - comment compatibility (SCX-BUY-P123#456 -> 123, legacy format
//      unchanged, <= 31 characters, parser untouched - the mirror
//      below reproduces the EXACT operations of the production parser
//      CPositionLifecycleManager::ParseEntryDecisionId:
//      StringFind(comment,"-P") + StringSubstr(ppos+2) +
//      StringToInteger(stops at first non-digit))
//
//  All counter tests use private per-test files under
//  Common\Files\ExecutionTest\ - NEVER the production counter path
//  Execution\execution_seq.dat.
//+------------------------------------------------------------------+
#ifndef __TEST_EXECUTION_IDENTITY_MQH__
#define __TEST_EXECUTION_IDENTITY_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/ExecutionIdentity.mqh"

string ExecutionIdTestCounterPath(const string name)
{
   return "ExecutionTest\\t_" + name + ".seq";
}

void ExecutionIdResetCounterFile(const string path)
{
   FileDelete(path, FILE_COMMON);
}

//--- Write a raw counter file content (test-only; simulates external
//    states incl. torn writes and checksum mismatches).
void ExecutionIdWriteCounterFile(const string path, const string content)
{
   int h = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_COMMON);
   if(h != INVALID_HANDLE)
   {
      FileWriteString(h, content);
      FileClose(h);
   }
}

string ExecutionIdChecksumLine(const ulong seq)
{
   return IntegerToString((long)(seq ^ 0xA5A5A5A5A5A5A5A5));
}

TestCounters RunExecutionIdentityTests(void)
{
   TestCounters counters;
   SUITE_BEGIN("ExecutionIdentity");

   // Counter files live under Common\Files\ExecutionTest\ - ensure the
   // directory exists before any test touches it (FileOpen does not
   // create directories).
   FolderCreate("ExecutionTest", FILE_COMMON);

   //================================================================
   // A. Identity uniqueness
   //================================================================

   // A1. Same (runId, seq) -> identical executionId, deterministic.
   {
      CExecutionIdentity id;
      id.Init("RUN-TEST-1", "2026.08.15 00:00:00", ExecutionIdTestCounterPath("a1"));
      string e1, e2;
      id.BuildExecutionId(42, e1);
      id.BuildExecutionId(42, e2);
      TEST_STR_EQ("EX-RUN-TEST-1-42", e1, "A1a: executionId format (BUILD expected EX-<runId>-<seq>)");
      TEST_STR_EQ(e1, e2, "A1b: same intent -> same executionId (deterministic build)");
   }

   // A2. Different seq -> different executionId.
   {
      CExecutionIdentity id;
      id.Init("RUN-TEST-1", "2026.08.15 00:00:00", ExecutionIdTestCounterPath("a2"));
      string e1, e2;
      id.BuildExecutionId(1, e1);
      id.BuildExecutionId(2, e2);
      TEST_TRUE(e1 != e2, "A2: different intents -> different executionIds");
   }

   // A3. Different runs -> different executionIds even for equal seq.
   {
      CExecutionIdentity id1, id2;
      id1.Init("RUN-TEST-1", "2026.08.15 00:00:00", ExecutionIdTestCounterPath("a3"));
      id2.Init("RUN-TEST-2", "2026.08.15 00:00:00", ExecutionIdTestCounterPath("a3"));
      string e1, e2;
      id1.BuildExecutionId(7, e1);
      id2.BuildExecutionId(7, e2);
      TEST_TRUE(e1 != e2, "A3: same seq, different runId -> different executionIds");
   }

   // A4. Allocation never returns the same seq twice within a run.
   {
      CExecutionIdentity id;
      id.Init("RUN-TEST-1", "2026.08.15 00:00:00", ExecutionIdTestCounterPath("a4"));
      ulong s1, s2, s3;
      id.AllocateSeq(s1);
      id.AllocateSeq(s2);
      id.AllocateSeq(s3);
      TEST_TRUE(s1 != s2 && s2 != s3 && s1 != s3, "A4: allocations are pairwise distinct");
   }

   //================================================================
   // B. Counter protocol: fresh file, monotonicity, persistence
   //================================================================

   // B1. Missing counter file -> created fresh; first allocation = 1.
   {
      string path = ExecutionIdTestCounterPath("b1");
      ExecutionIdResetCounterFile(path);
      CExecutionIdentity id;
      bool ok = id.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      TEST_TRUE(ok, "B1a: Init on missing counter succeeds (fresh create)");
      ulong seq;
      id.AllocateSeq(seq);
      TEST_TRUE(seq == 1, "B1b: first allocation is 1");
      TEST_TRUE(FileIsExist(path, FILE_COMMON), "B1c: counter file created on disk");
      ExecutionIdResetCounterFile(path);
   }

   // B2. Persistence across instances: a returned seq is never reused.
   {
      string path = ExecutionIdTestCounterPath("b2");
      ExecutionIdResetCounterFile(path);
      CExecutionIdentity a;
      a.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong s1 = 0;
      for(int i = 0; i < 5; i++)
         a.AllocateSeq(s1);
      TEST_TRUE(s1 == 5, "B2a: allocator reached 5 (monotonic within run)");
      CExecutionIdentity b;
      b.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong s6;
      b.AllocateSeq(s6);
      TEST_TRUE(s6 == 6, "B2b: restarted allocator continues at 6 (reserved seq 1..5 never reused)");
      ExecutionIdResetCounterFile(path);
   }

   // B3. Restart crash-window: a durable seq is never re-issued after
   //     a simulated restart (the crash happened AFTER allocation was
   //     durable, i.e. the seq was already handed out).
   {
      string path = ExecutionIdTestCounterPath("b3");
      ExecutionIdResetCounterFile(path);
      CExecutionIdentity a;
      a.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong s = 0;
      for(int i = 0; i < 7; i++)
         a.AllocateSeq(s);
      TEST_TRUE(s == 7, "B3a: allocation 7 durable");
      CExecutionIdentity b;
      b.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong s2;
      b.AllocateSeq(s2);
      TEST_TRUE(s2 == 8, "B3b: after restart, 7 is never re-issued (next is 8)");
      ExecutionIdResetCounterFile(path);
   }

   //================================================================
   // C. Counter fail-safes: corruption, torn write, width, rollback
   //================================================================

   // C1. Corrupt content (non-numeric) -> COUNTER_CORRUPT, refuse.
   {
      string path = ExecutionIdTestCounterPath("c1");
      ExecutionIdResetCounterFile(path);
      ExecutionIdWriteCounterFile(path, "garbage data\nnot a number\n");
      CExecutionIdentity id;
      id.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      TEST_TRUE(id.State() == IDENTITY_STATE_COUNTER_CORRUPT, "C1a: corrupt counter -> COUNTER_CORRUPT");
      ulong seq;
      TEST_TRUE(!id.AllocateSeq(seq), "C1b: allocation refused on corrupt counter");
      TEST_TRUE(!id.IsUsable(), "C1c: identity not usable while corrupt");
      ExecutionIdResetCounterFile(path);
   }

   // C2. Checksum mismatch -> COUNTER_CORRUPT, refuse (never trusts the value).
   {
      string path = ExecutionIdTestCounterPath("c2");
      ExecutionIdResetCounterFile(path);
      ExecutionIdWriteCounterFile(path, "42\n0\n"); // wrong checksum for 42
      CExecutionIdentity id;
      id.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      TEST_TRUE(id.State() == IDENTITY_STATE_COUNTER_CORRUPT, "C2a: checksum mismatch -> COUNTER_CORRUPT");
      ulong seq;
      TEST_TRUE(!id.AllocateSeq(seq), "C2b: allocation refused (checksum mismatch)");
      ExecutionIdResetCounterFile(path);
   }

   // C3. Torn write (missing checksum line) -> COUNTER_CORRUPT (fail-safe
   //     for the crash-during-write window; never auto-recovers).
   {
      string path = ExecutionIdTestCounterPath("c3");
      ExecutionIdResetCounterFile(path);
      ExecutionIdWriteCounterFile(path, "43\n"); // torn: value without checksum
      CExecutionIdentity id;
      id.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      TEST_TRUE(id.State() == IDENTITY_STATE_COUNTER_CORRUPT, "C3a: torn write -> COUNTER_CORRUPT");
      ulong seq;
      TEST_TRUE(!id.AllocateSeq(seq), "C3b: allocation refused on torn write");
      ExecutionIdResetCounterFile(path);
   }

   // C4. Width guard: seq above the comment-budget cap -> BLOCKED_WIDTH.
   {
      CExecutionIdentity id;
      id.Init("RUN-TEST-1", "2026.08.15 00:00:00", ExecutionIdTestCounterPath("c4"));
      id.SetMonotonicFloor(EXEC_ID_MAX_SEQ);
      ulong seq;
      TEST_TRUE(!id.AllocateSeq(seq), "C4a: allocation refused at width cap");
      TEST_TRUE(id.State() == IDENTITY_STATE_BLOCKED_WIDTH, "C4b: state BLOCKED_WIDTH");
   }

   // C5. Monotonic floor: allocations never go below floor+1 (the future
   //     ledger high-water mark from B25-03C; rollback protection).
   {
      string path = ExecutionIdTestCounterPath("c5");
      ExecutionIdResetCounterFile(path);
      CExecutionIdentity a;
      a.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong s;
      for(int i = 0; i < 5; i++)
         a.AllocateSeq(s); // file now at 5
      // External rollback simulation: counter file restored to an older value.
      ExecutionIdWriteCounterFile(path, "2\n" + ExecutionIdChecksumLine(2) + "\n");
      CExecutionIdentity b;
      b.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong sFloor;
      b.SetMonotonicFloor(5); // the known high-water mark (ledger role)
      b.AllocateSeq(sFloor);
      TEST_TRUE(sFloor == 6, "C5: floor blocks rolled-back counter (next is 6, never 3)");
      ExecutionIdResetCounterFile(path);
   }

   // C6. Without the floor the rollback hazard is visible (documents why
   //     B25-03C must feed the ledger high-water mark - boundary test).
   {
      string path = ExecutionIdTestCounterPath("c6");
      ExecutionIdResetCounterFile(path);
      CExecutionIdentity a;
      a.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong s;
      for(int i = 0; i < 5; i++)
         a.AllocateSeq(s);
      ExecutionIdWriteCounterFile(path, "2\n" + ExecutionIdChecksumLine(2) + "\n");
      CExecutionIdentity b;
      b.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong sNoFloor;
      b.AllocateSeq(sNoFloor);
      TEST_TRUE(sNoFloor == 3, "C6: no-floor allocator follows the rolled-back file (hazard recorded)");
      ExecutionIdResetCounterFile(path);
   }

   //================================================================
   // D. Comment compatibility (mirror of the frozen production parser)
   //================================================================

   // D1. New format -> decision id 123.
   {
      CExecutionIdentity id;
      long d;
      id.ParseDecisionId("SCX-BUY-P123#456", d);
      TEST_TRUE(d == 123, "D1: SCX-BUY-P123#456 -> 123 (production parser contract)");
   }

   // D2. SELL variant -> decision id 123.
   {
      CExecutionIdentity id;
      long d;
      id.ParseDecisionId("SCX-SELL-P123#456", d);
      TEST_TRUE(d == 123, "D2: SCX-SELL-P123#456 -> 123");
   }

   // D3. Legacy format unchanged -> 123.
   {
      CExecutionIdentity id;
      long d;
      id.ParseDecisionId("SCX-BUY-P123", d);
      TEST_TRUE(d == 123, "D3: legacy SCX-BUY-P123 -> 123");
   }

   // D4. Broker-appended text -> 123.
   {
      CExecutionIdentity id;
      long d;
      id.ParseDecisionId("SCX-BUY-P123#456 [broker notes]", d);
      TEST_TRUE(d == 123, "D4: broker-appended suffix tolerated (still 123)");
   }

   // D5. Tail stripped by broker -> 123 (degrades to legacy).
   {
      CExecutionIdentity id;
      long d;
      id.ParseDecisionId("SCX-BUY-P123", d);
      TEST_TRUE(d == 123, "D5: tail-stripped comment still yields 123");
   }

   // D6. Negative cases -> false (no -P token, no digits).
   {
      CExecutionIdentity id;
      long d;
      TEST_TRUE(!id.ParseDecisionId("SCX-BUY-P", d), "D6a: empty id after -P -> false");
      TEST_TRUE(!id.ParseDecisionId("no token here", d), "D6b: no -P token -> false");
      TEST_TRUE(!id.ParseDecisionId("", d), "D6c: empty comment -> false");
      TEST_TRUE(!id.ParseDecisionId("-P", d), "D6d: bare -P -> false");
   }

   // D7. Large decision id survives the parse.
   {
      CExecutionIdentity id;
      long d;
      id.ParseDecisionId("SCX-BUY-P2147483647#1", d);
      TEST_TRUE(d == 2147483647, "D7: large decision id 2147483647 preserved");
   }

   // D8. seq tail parse (future reconciler input).
   {
      CExecutionIdentity id;
      ulong seq;
      TEST_TRUE(id.ParseSeqFromComment("SCX-BUY-P123#456", seq), "D8a: tail parse ok");
      TEST_TRUE(seq == 456, "D8b: tail seq == 456");
      TEST_TRUE(!id.ParseSeqFromComment("SCX-BUY-P123", seq), "D8c: legacy comment has no tail -> false");
   }

   // D9. Round-trip: build -> parse -> identical fields.
   {
      CExecutionIdentity id;
      string c;
      id.BuildComment("BUY", 123, 456, c);
      long d;
      ulong s;
      TEST_TRUE(id.ParseDecisionId(c, d), "D9a: round-trip parse id");
      TEST_TRUE(d == 123, "D9b: round-trip id == 123");
      TEST_TRUE(id.ParseSeqFromComment(c, s), "D9c: round-trip parse seq");
      TEST_TRUE(s == 456, "D9d: round-trip seq == 456");
   }

   // D10. Build format exact.
   {
      CExecutionIdentity id;
      string c;
      id.BuildComment("BUY", 123, 456, c);
      TEST_STR_EQ("SCX-BUY-P123#456", c, "D10a: BUY build format");
      id.BuildComment("SELL", 123, 456, c);
      TEST_STR_EQ("SCX-SELL-P123#456", c, "D10b: SELL build format");
   }

   // D11. Comment length budget: worst realistic case <= 31 chars.
   {
      CExecutionIdentity id;
      string c;
      TEST_TRUE(id.BuildComment("SELL", 2147483647, 99999999, c), "D11a: worst-case build ok");
      TEST_TRUE(StringLen(c) <= 31, "D11b: worst-case length <= 31 (got " + IntegerToString(StringLen(c)) + ")");
   }

   // D12. Length guard refuses an over-long comment.
   {
      CExecutionIdentity id;
      string c;
      TEST_TRUE(!id.BuildComment("SELL", 2147483647000, 99999999, c), "D12: over-long comment refused");
   }

   // D13. Side validation: only BUY/SELL.
   {
      CExecutionIdentity id;
      string c;
      TEST_TRUE(!id.BuildComment("HEDGE", 123, 456, c), "D13: unknown side refused");
   }

   //================================================================
   // E. Lifecycle guards
   //================================================================

   // E1. Allocation before Init -> false, NOT_INITIALIZED.
   {
      CExecutionIdentity id;
      ulong seq;
      TEST_TRUE(!id.AllocateSeq(seq), "E1a: allocate before Init refused");
      TEST_TRUE(id.State() == IDENTITY_STATE_NOT_INITIALIZED, "E1b: state NOT_INITIALIZED");
   }

   // E2. executionId build before Init -> false (no runId).
   {
      CExecutionIdentity id;
      string e;
      TEST_TRUE(!id.BuildExecutionId(1, e), "E2: executionId build before Init refused");
   }

   // E3. State names are non-empty for every state.
   {
      CExecutionIdentity id;
      TEST_TRUE(StringLen(id.StateName()) > 0, "E3: StateName non-empty");
   }

   // E4. Re-init with a different counter path works (fresh identity).
   {
      string path = ExecutionIdTestCounterPath("e4");
      ExecutionIdResetCounterFile(path);
      CExecutionIdentity id;
      TEST_TRUE(id.Init("RUN-TEST-1", "2026.08.15 00:00:00", path), "E4a: Init ok");
      ulong seq;
      id.AllocateSeq(seq);
      TEST_TRUE(seq == 1, "E4b: re-initialized identity allocates from 1");
      ExecutionIdResetCounterFile(path);
   }

   //================================================================
   // F. Crash-window table (design Section 23.2 points 1-10)
   //================================================================

   // F1. Crash before allocation: no intent, counter untouched.
   {
      string path = ExecutionIdTestCounterPath("f1");
      ExecutionIdResetCounterFile(path);
      // (no allocation performed)
      CExecutionIdentity id;
      id.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      TEST_TRUE(id.State() == IDENTITY_STATE_OK, "F1: no allocation -> state OK, nothing to recover");
      ExecutionIdResetCounterFile(path);
   }

   // F2. Crash after allocation (durable) but before use: seq gap, next
   //     run never re-issues the durable value.
   {
      string path = ExecutionIdTestCounterPath("f2");
      ExecutionIdResetCounterFile(path);
      CExecutionIdentity a;
      a.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong s;
      a.AllocateSeq(s);
      TEST_TRUE(s == 1, "F2a: allocation 1 durable");
      CExecutionIdentity b;
      b.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      ulong s2;
      b.AllocateSeq(s2);
      TEST_TRUE(s2 == 2, "F2b: crash window - durable seq never re-issued");
      ExecutionIdResetCounterFile(path);
   }

   // F3. Crash during counter write (torn) -> corrupt fail-safe, never a
   //     silently advanced counter.
   {
      string path = ExecutionIdTestCounterPath("f3");
      ExecutionIdResetCounterFile(path);
      ExecutionIdWriteCounterFile(path, "5\n12345\n"); // torn checksum
      CExecutionIdentity id;
      id.Init("RUN-TEST-1", "2026.08.15 00:00:00", path);
      TEST_TRUE(id.State() == IDENTITY_STATE_COUNTER_CORRUPT, "F3a: torn checksum -> COUNTER_CORRUPT");
      ulong seq;
      TEST_TRUE(!id.AllocateSeq(seq), "F3b: refuse (no guess about the torn value)");
      ExecutionIdResetCounterFile(path);
   }

   SUITE_END("ExecutionIdentity");
   return counters;
}

#endif
