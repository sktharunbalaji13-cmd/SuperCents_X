//+------------------------------------------------------------------+
//|                              ExecutionIdentity.mqh               |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03A |
//+------------------------------------------------------------------+
//  B25-03A - Canonical Execution Identity (SENIOR-AUTHORIZED).
//
//  This component owns the durable execution sequence counter and the
//  execution identity / order-comment encoding. Scope is strictly
//  bounded to B25-03A: nothing here executes trades, records deals or
//  reconciles - it exposes the pure identity primitives that later
//  phases (B25-03C+) will wire into the execution pipeline.
//
//  Crash-window protocol (design Section 23.2):
//    1. Reserve-before-use: the counter file is advanced and flushed
//       BEFORE a sequence number is handed out. A crash after the
//       reservation can never re-issue the value.
//    2. The reservation is verified by read-back before use; a torn or
//       undurable write degrades to COUNTER_CORRUPT and refuses to
//       allocate (never guesses, never auto-recovers).
//    3. A monotonic floor (future ledger high-water mark from B25-03C)
//       prevents a rolled-back counter file from re-issuing values.
//    4. A missing counter file is a legal fresh start; anything else
//       that does not parse cleanly is corruption.
//
//  Comment format (<= 31 chars, legacy-compatible):
//      SCX-BUY-P<decisionId>#<seq>      /      SCX-SELL-P<decisionId>#<seq>
//  The legacy form SCX-<side>-P<decisionId> (no #<seq> tail) remains
//  fully parseable. ParseDecisionId mirrors the frozen production
//  parser CPositionLifecycleManager::ParseEntryDecisionId EXACTLY
//  (StringFind "-P" + StringSubstr(ppos+2) + StringToInteger, which
//  stops at the first non-digit).
//+------------------------------------------------------------------+
#ifndef __EXECUTION_IDENTITY_MQH__
#define __EXECUTION_IDENTITY_MQH__

#define EXEC_ID_MAX_SEQ            99999999
#define EXEC_ID_COMMENT_MAX_LEN    31
#define EXEC_ID_DEFAULT_COUNTER_PATH "Execution\\execution_seq.dat"
#define EXEC_ID_COUNTER_MASK       0xA5A5A5A5A5A5A5A5

enum ENUM_EXEC_IDENTITY_STATE
{
   IDENTITY_STATE_NOT_INITIALIZED = 0,
   IDENTITY_STATE_OK,
   IDENTITY_STATE_COUNTER_CORRUPT,
   IDENTITY_STATE_BLOCKED_WIDTH
};

class CExecutionIdentity
{
private:
   string m_counterPath;
   string m_runId;
   string m_buildTag;
   ulong  m_lastAllocated;
   ulong  m_floor;
   ENUM_EXEC_IDENTITY_STATE m_state;
   bool   m_initialized;

   static ulong Checksum(const ulong seq)
   {
      return seq ^ EXEC_ID_COUNTER_MASK;
   }

   static string ChecksumLine(const ulong seq)
   {
      return IntegerToString((long)Checksum(seq));
   }

   //--- Load the durable counter. Missing file => false-with-*no* value
   //    is NOT possible here: we distinguish via FileIsExist first.
   //    Returns true only when the file parses cleanly AND its checksum
   //    line matches (never trusts the value).
   bool ReadCounterFile(const string path, ulong &storedSeq) const
   {
      int h = FileOpen(path, FILE_READ | FILE_TXT | FILE_COMMON);
      if(h == INVALID_HANDLE)
         return false;
      string line1 = FileReadString(h);
      string line2 = FileReadString(h);
      FileClose(h);

      ulong val = (ulong)StringToInteger(line1);
      long  cs  = StringToInteger(line2);
      if(cs != (long)Checksum(val))
         return false;
      storedSeq = val;
      return true;
   }

   //--- Reserve seq: write "seq\r\n<checksum>\r\n", flush, close, then
   //    verify by read-back. Only a verified reservation succeeds.
   bool WriteCounterFile(const string path, const ulong seq)
   {
      int h = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_COMMON);
      if(h == INVALID_HANDLE)
         return false;
      FileWriteString(h, IntegerToString(seq) + "\r\n");
      FileWriteString(h, ChecksumLine(seq) + "\r\n");
      FileFlush(h);
      FileClose(h);

      h = FileOpen(path, FILE_READ | FILE_TXT | FILE_COMMON);
      if(h == INVALID_HANDLE)
         return false;
      string v1 = FileReadString(h);
      string v2 = FileReadString(h);
      FileClose(h);
      return ((ulong)StringToInteger(v1) == seq && StringToInteger(v2) == (long)Checksum(seq));
   }

public:
   CExecutionIdentity(void)
   {
      Reset();
   }

   void Reset(void)
   {
      m_counterPath   = "";
      m_runId         = "";
      m_buildTag      = "";
      m_lastAllocated = 0;
      m_floor         = 0;
      m_state         = IDENTITY_STATE_NOT_INITIALIZED;
      m_initialized   = false;
   }

   //--- Configure identity for a run. Loads the durable counter:
   //    missing => fresh start (OK), unreadable/invalid => COUNTER_CORRUPT
   //    (fail-safe; the caller must NOT allocate against a corrupt
   //    counter - any later AllocateSeq is refused).
   bool Init(const string runId, const string buildTag, const string counterPath)
   {
      m_runId         = runId;
      m_buildTag      = buildTag;
      m_counterPath   = counterPath;
      m_initialized   = true;

      // FileOpen does not create directories - ensure the counter
      // directory exists (idempotent; FolderCreate on an existing
      // directory is a harmless no-op).
      int slash = StringFind(counterPath, "\\");
      if(slash >= 0)
         FolderCreate(StringSubstr(counterPath, 0, slash), FILE_COMMON);

      if(!FileIsExist(counterPath, FILE_COMMON))
      {
         m_lastAllocated = 0;
         m_state         = IDENTITY_STATE_OK;
         return true;
      }

      ulong stored = 0;
      if(!ReadCounterFile(m_counterPath, stored))
      {
         m_state = IDENTITY_STATE_COUNTER_CORRUPT;
         return false;
      }
      m_lastAllocated = stored;
      m_state         = IDENTITY_STATE_OK;
      return true;
   }

   //--- Reserve the next sequence number (reserve-before-use, durable).
   bool AllocateSeq(ulong &outSeq)
   {
      if(!m_initialized)
         return false;
      if(m_state != IDENTITY_STATE_OK)
         return false;

      ulong candidate = (m_lastAllocated > m_floor ? m_lastAllocated : m_floor) + 1;
      if(candidate > EXEC_ID_MAX_SEQ)
      {
         m_state = IDENTITY_STATE_BLOCKED_WIDTH;
         return false;
      }

      if(!WriteCounterFile(m_counterPath, candidate))
      {
         m_state = IDENTITY_STATE_COUNTER_CORRUPT;
         return false;
      }

      m_lastAllocated = candidate;
      outSeq          = candidate;
      return true;
   }

   //--- Monotonic floor: allocations never go below floor+1. This is the
   //    hook for the B25-03C ledger high-water mark (restart recovery
   //    feeds the highest durably-recorded sequence here), which blocks
   //    rolled-back or replayed counter files.
   void SetMonotonicFloor(const ulong floor)
   {
      m_floor = floor;
   }

   //--- Canonical execution id: EX-<runId>-<seq>.
   bool BuildExecutionId(const ulong seq, string &executionId) const
   {
      if(!m_initialized)
         return false;
      executionId = "EX-" + m_runId + "-" + IntegerToString(seq);
      return true;
   }

   //--- Order comment: SCX-<side>-P<decisionId>#<seq> (legacy-compatible,
   //    <= EXEC_ID_COMMENT_MAX_LEN chars). side must be BUY or SELL.
   bool BuildComment(const string side, const long decisionId, const ulong seq, string &comment) const
   {
      if(side != "BUY" && side != "SELL")
         return false;
      comment = StringFormat("SCX-%s-P%lld#%llu", side, decisionId, seq);
      if(StringLen(comment) > EXEC_ID_COMMENT_MAX_LEN)
         return false;
      return true;
   }

   //--- Decision id from any comment form. Mirrors the frozen production
   //    parser CPositionLifecycleManager::ParseEntryDecisionId exactly:
   //    StringFind("-P") + StringSubstr(ppos+2) + StringToInteger (which
   //    stops at the first non-digit). "SCX-BUY-P123#456" -> 123.
   bool ParseDecisionId(const string comment, long &decisionId) const
   {
      int ppos = StringFind(comment, "-P");
      if(ppos < 0)
         return false;
      string numStr = StringSubstr(comment, ppos + 2);
      if(numStr == "")
         return false;
      decisionId = StringToInteger(numStr);
      return true;
   }

   //--- Sequence tail from the new comment form: "SCX-BUY-P123#456" -> 456.
   //    Legacy comments without the # tail return false.
   bool ParseSeqFromComment(const string comment, ulong &seq) const
   {
      int hpos = StringFind(comment, "#");
      if(hpos < 0)
         return false;
      string numStr = StringSubstr(comment, hpos + 1);
      if(numStr == "")
         return false;
      seq = (ulong)StringToInteger(numStr);
      return true;
   }

   ulong LastSeq(void) const
   {
      return m_lastAllocated;
   }

   ENUM_EXEC_IDENTITY_STATE State(void) const
   {
      return m_state;
   }

   string StateName(void) const
   {
      switch(m_state)
      {
         case IDENTITY_STATE_NOT_INITIALIZED: return "NOT_INITIALIZED";
         case IDENTITY_STATE_OK:              return "OK";
         case IDENTITY_STATE_COUNTER_CORRUPT: return "COUNTER_CORRUPT";
         case IDENTITY_STATE_BLOCKED_WIDTH:   return "BLOCKED_WIDTH";
      }
      return "UNKNOWN";
   }

   bool IsUsable(void) const
   {
      return m_initialized && (m_state == IDENTITY_STATE_OK);
   }
};

#endif
