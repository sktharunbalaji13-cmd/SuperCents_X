//+------------------------------------------------------------------+
//|                           ExecutionLedger.mqh                     |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03C-A |
//+------------------------------------------------------------------+
//  B25-03C-A - Execution Ledger Core: versioned header, | -delimited
//  append-only event format, SHA-256 integrity, append + flush,
//  replay reader, eventSeq derivation from the last valid tail,
//  torn-tail detection/recovery, mid-file corruption -> BLOCK,
//  schema/version validation, executionSeq-gap acceptance.
//
//  GREEN PHASE (truthful implementation per design doc
//  docs/Sprint25B_B25-03C_ExecutionLedger_Design.md, Phases 3-10).
//
//  File format (frozen):
//    header : LEDGER|<schema>|<createdRunId>|<buildTag>|<gitHead>|
//             <terminalBuild>|<createdTime>|SHA256(body)
//    record : EVT|<eventSeq>|<executionId>|<eventType>|<timestamp>|
//             <stateFrom>|<stateTo>|<payload...>|SHA256(body)
//  The payload field is opaque and may itself contain '|'; it is
//  replayed as the join of every field after <stateTo> up to (not
//  including) the trailing checksum field.
//
//  eventSeq is the per-event ordering: contiguous, derived from the
//  last VALID record in the file (tail+1), never from memory.
//  executionSeq (inside the executionId) is reserve-before-use:
//  gaps are legal. CORRUPTION events are part of the vocabulary and
//  record truncation evidence. Nothing here touches TradeManager,
//  OrderSend, recovery, reconciliation, dedup, broker inspection or
//  OnTradeTransaction - B25-03C-B..F are NOT AUTHORIZED.
//+------------------------------------------------------------------+
#ifndef __EXECUTION_LEDGER_MQH__
#define __EXECUTION_LEDGER_MQH__

//--- ledger constants (final)
#define EXEC_LEDGER_MAGIC     "LEDGER"
#define EXEC_LEDGER_SCHEMA    1

//--- event types (final vocabulary, Phase 6 of the design)
#define LEDGER_EVENT_INTENT       "INTENT"
#define LEDGER_EVENT_SENT         "SENT"
#define LEDGER_EVENT_REJECTED     "REJECTED"
#define LEDGER_EVENT_UNKNOWN      "UNKNOWN"
#define LEDGER_EVENT_DEAL_IN      "DEAL_IN"
#define LEDGER_EVENT_RECONCILED   "RECONCILED"
#define LEDGER_EVENT_BLOCKED      "BLOCKED"
#define LEDGER_EVENT_CORRUPTION   "CORRUPTION"
#define LEDGER_EVENT_RUN_END      "RUN_END"

//--- scan classification (final)
enum ENUM_LEDGER_SCAN_RESULT
{
    LEDGER_SCAN_CLEAN,            // all records valid, eventSeq contiguous
    LEDGER_SCAN_HEADER_CORRUPT,   // header magic/schema/checksum invalid
    LEDGER_SCAN_TORN_TAIL,        // final record truncated (interrupted write)
    LEDGER_SCAN_MID_FILE_CORRUPT, // malformed/tampered record mid-file -> BLOCK
    LEDGER_SCAN_SEQ_VIOLATION     // eventSeq hole or duplicate -> BLOCK
};

//--- one replayed ledger event (final)
struct ExecutionLedgerEvent
{
    ulong    eventSeq;    // per-event ordering, contiguous, tail-derived
    string   executionId; // EX-<runId>-<executionSeq>
    string   eventType;   // LEDGER_EVENT_* vocabulary
    datetime timestamp;   // informational; ordering authority is eventSeq
    string   stateFrom;
    string   stateTo;
    string   payload;     // execution-truth payload (opaque, may contain |)
    string   checksum;    // recorded SHA-256 hex of the record body
    string   raw;         // original line (verbatim evidence)
};

//--- SHA-256 hex of any string (lowercase). Deterministic; empty on error.
string LedgerChecksumHex(const string data)
{
    uchar bytes[];
    int n = StringToCharArray(data, bytes, 0, StringLen(data), CP_UTF8);
    if(n <= 0)
        return "";
    uchar key[];
    uchar digest[];
    if(CryptEncode(CRYPT_HASH_SHA256, bytes, key, digest) != 32)
        return "";
    string hex = "";
    for(int i = 0; i < 32; i++)
        hex += StringFormat("%02x", (int)digest[i]);
    return hex;
}

//--- structural + recompute checksum comparison
bool LedgerChecksumMatches(const string data, const string expectedHex)
{
    if(StringLen(expectedHex) != 64)
        return false;
    return (LedgerChecksumHex(data) == expectedHex);
}

//--- header validation: magic + schema version + field count + checksum
bool LedgerValidateHeader(const string line, string &error)
{
    error = "";
    if(StringLen(line) < 20)
    {
        error = "header too short";
        return false;
    }
    string parts[];
    int n = StringSplit(line, '|', parts);
    if(n != 8)
    {
        error = "header field count " + IntegerToString(n) + " != 8";
        return false;
    }
    if(parts[0] != EXEC_LEDGER_MAGIC)
    {
        error = "header magic mismatch";
        return false;
    }
    if(parts[1] != IntegerToString(EXEC_LEDGER_SCHEMA))
    {
        error = "header schema version " + parts[1] + " != " + IntegerToString(EXEC_LEDGER_SCHEMA);
        return false;
    }
    string checksum = parts[7];
    string body = StringSubstr(line, 0, StringLen(line) - StringLen(checksum) - 1);
    if(!LedgerChecksumMatches(body, checksum))
    {
        error = "header checksum mismatch";
        return false;
    }
    return true;
}

//--- header builder
string LedgerBuildHeader(const string createdRunId, const string buildTag,
                         const string gitHead, const string terminalBuild,
                         const datetime createdTime)
{
    string body = StringFormat("%s|%d|%s|%s|%s|%s|%s",
        EXEC_LEDGER_MAGIC, EXEC_LEDGER_SCHEMA, createdRunId, buildTag,
        gitHead, terminalBuild, TimeToString(createdTime));
    return body + "|" + LedgerChecksumHex(body);
}

//--- record builder (checksum covers the full body including EVT prefix)
string LedgerBuildRecord(const ulong eventSeq, const string executionId,
                         const string eventType, const datetime timestamp,
                         const string stateFrom, const string stateTo,
                         const string payload)
{
    string body = StringFormat("EVT|%llu|%s|%s|%s|%s|%s|%s",
        eventSeq, executionId, eventType, TimeToString(timestamp),
        stateFrom, stateTo, payload);
    return body + "|" + LedgerChecksumHex(body);
}

bool LedgerIsDigits(const string s)
{
    int len = StringLen(s);
    if(len == 0)
        return false;
    for(int i = 0; i < len; i++)
    {
        ushort c = StringGetCharacter(s, i);
        if(c < '0' || c > '9')
            return false;
    }
    return true;
}

bool LedgerIsEventType(const string t)
{
    return (t == LEDGER_EVENT_INTENT || t == LEDGER_EVENT_SENT ||
            t == LEDGER_EVENT_REJECTED || t == LEDGER_EVENT_UNKNOWN ||
            t == LEDGER_EVENT_DEAL_IN || t == LEDGER_EVENT_RECONCILED ||
            t == LEDGER_EVENT_BLOCKED || t == LEDGER_EVENT_CORRUPTION ||
            t == LEDGER_EVENT_RUN_END);
}

//--- record parse: strict - shape, eventSeq digits, timestamp, eventType
//    vocabulary, checksum verification. Never trusts field count alone.
bool LedgerParseRecord(const string line, ExecutionLedgerEvent &ev, string &error)
{
    ev.raw = line;
    if(StringLen(line) < 10)
    {
        error = "record too short";
        return false;
    }
    string parts[];
    int n = StringSplit(line, '|', parts);
    if(n < 9)
    {
        error = "malformed record: too few fields";
        return false;
    }
    if(parts[0] != "EVT")
    {
        error = "malformed record: missing EVT prefix";
        return false;
    }
    if(!LedgerIsDigits(parts[1]))
    {
        error = "malformed record: non-numeric eventSeq";
        return false;
    }
    datetime ts = StringToTime(parts[4]);
    if(ts <= 0)
    {
        error = "malformed record: invalid timestamp";
        return false;
    }
    if(!LedgerIsEventType(parts[3]))
    {
        error = "malformed record: unknown eventType";
        return false;
    }
    string checksum = parts[n - 1];
    string body = StringSubstr(line, 0, StringLen(line) - StringLen(checksum) - 1);
    if(!LedgerChecksumMatches(body, checksum))
    {
        error = "checksum mismatch";
        return false;
    }
    ev.eventSeq    = (ulong)StringToInteger(parts[1]);
    ev.executionId = parts[2];
    ev.eventType   = parts[3];
    ev.timestamp   = ts;
    ev.stateFrom   = parts[5];
    ev.stateTo     = parts[6];
    ev.payload     = "";
    for(int i = 7; i < n - 1; i++)
    {
        ev.payload += (i > 7 ? "|" : "") + parts[i];
    }
    ev.checksum = checksum;
    return true;
}

//--- executionSeq extraction from EX-<runId>-<executionSeq>
ulong LedgerExtractExecutionSeq(const string executionId)
{
    string parts[];
    int n = StringSplit(executionId, '-', parts);
    if(n < 2)
        return 0;
    string seq = parts[n - 1];
    if(StringLen(seq) == 0)
        return 0;
    return (ulong)StringToInteger(seq);
}

//--- high-water executionSeq over INTENT records. Reserve-before-use
//    semantics: gaps are legal and never rejected (adversarial case A).
//    Returns false when no INTENT exists.
bool LedgerHighWaterExecutionSeq(const ExecutionLedgerEvent &events[],
                                 const int count, ulong &maxSeq)
{
    bool found = false;
    maxSeq = 0;
    for(int i = 0; i < count; i++)
    {
        if(events[i].eventType == LEDGER_EVENT_INTENT)
        {
            ulong seq = LedgerExtractExecutionSeq(events[i].executionId);
            if(seq > maxSeq)
                maxSeq = seq;
            found = true;
        }
    }
    return found;
}

//--- open for append: missing file -> create + header + flush;
//    existing file -> header MUST validate (BLOCK otherwise).
bool LedgerOpenOrCreate(const string path, const string createdRunId,
                        const string buildTag, const string gitHead,
                        const string terminalBuild)
{
    FolderCreate("Execution", FILE_COMMON);
    if(FileIsExist(path, FILE_COMMON))
    {
        int h = FileOpen(path, FILE_READ | FILE_TXT | FILE_COMMON);
        if(h == INVALID_HANDLE)
            return false;
        string first = FileReadString(h);
        StringTrimRight(first);
        FileClose(h);
        string err = "";
        if(!LedgerValidateHeader(first, err))
            return false;
        return true;
    }
    int hf = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(hf == INVALID_HANDLE)
        return false;
    FileWriteString(hf, LedgerBuildHeader(createdRunId, buildTag, gitHead,
                     terminalBuild, TimeCurrent()) + "\r\n");
    FileFlush(hf);
    FileClose(hf);
    return true;
}

//--- append: refuses any ledger state other than CLEAN (BLOCK on
//    header/mid-file corruption, torn tail, seq violation). eventSeq
//    is derived from the last valid record: tail + 1.
bool LedgerAppendEvent(const string path, const string executionId,
                       const string eventType, const datetime timestamp,
                       const string stateFrom, const string stateTo,
                       const string payload, ulong &eventSeqOut)
{
    ExecutionLedgerEvent evs[];
    string cinfo = "";
    if(LedgerScan(path, evs, cinfo) != LEDGER_SCAN_CLEAN)
        return false;
    ulong tail = (ArraySize(evs) > 0 ? evs[ArraySize(evs) - 1].eventSeq : 0);
    eventSeqOut = tail + 1;
    string line = LedgerBuildRecord(eventSeqOut, executionId, eventType,
                                    timestamp, stateFrom, stateTo, payload);
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(h == INVALID_HANDLE)
        return false;
    FileSeek(h, 0, SEEK_END);
    FileWriteString(h, line + "\r\n");
    FileFlush(h);
    FileClose(h);
    return true;
}

//--- last VALID eventSeq in the file (0 when none). BLOCKed states
//    (header/mid-file corruption, seq violation) return false.
bool LedgerTailEventSeq(const string path, ulong &lastEventSeq)
{
    ExecutionLedgerEvent evs[];
    string cinfo = "";
    ENUM_LEDGER_SCAN_RESULT sc = LedgerScan(path, evs, cinfo);
    if(sc != LEDGER_SCAN_CLEAN && sc != LEDGER_SCAN_TORN_TAIL)
        return false;
    lastEventSeq = (ArraySize(evs) > 0 ? evs[ArraySize(evs) - 1].eventSeq : 0);
    return true;
}

//--- full replay + classification. Every line is validated; the first
//    failing record decides the result. Valid records before a mid-file
//    corruption are returned; nothing after it is trusted.
ENUM_LEDGER_SCAN_RESULT LedgerScan(const string path, ExecutionLedgerEvent &events[],
                                   string &corruptionInfo)
{
    ArrayResize(events, 0);
    corruptionInfo = "";
    int h = FileOpen(path, FILE_READ | FILE_TXT | FILE_COMMON);
    if(h == INVALID_HANDLE)
    {
        corruptionInfo = "cannot open ledger file";
        return LEDGER_SCAN_HEADER_CORRUPT;
    }
    string lines[];
    while(!FileIsEnding(h))
    {
        string ln = FileReadString(h);
        StringTrimRight(ln);
        if(StringLen(ln) == 0)
            continue;
        int n = ArraySize(lines);
        ArrayResize(lines, n + 1);
        lines[n] = ln;
    }
    FileClose(h);

    int total = ArraySize(lines);
    if(total == 0)
    {
        corruptionInfo = "empty ledger file";
        return LEDGER_SCAN_HEADER_CORRUPT;
    }
    if(!LedgerValidateHeader(lines[0], corruptionInfo))
        return LEDGER_SCAN_HEADER_CORRUPT;

    ulong prev = 0;
    bool first = true;
    for(int i = 1; i < total; i++)
    {
        ExecutionLedgerEvent ev;
        string err = "";
        if(!LedgerParseRecord(lines[i], ev, err))
        {
            if(i == total - 1 && StringFind(lines[i], "EVT|", 0) == 0)
            {
                corruptionInfo = err + " (torn tail)";
                return LEDGER_SCAN_TORN_TAIL;
            }
            corruptionInfo = err + " | line=" + lines[i];
            return LEDGER_SCAN_MID_FILE_CORRUPT;
        }
        if(first)
        {
            if(ev.eventSeq != 1)
            {
                corruptionInfo = "eventSeq hole: first event " + IntegerToString((int)ev.eventSeq) + " != 1";
                return LEDGER_SCAN_SEQ_VIOLATION;
            }
            first = false;
        }
        else if(ev.eventSeq != prev + 1)
        {
            corruptionInfo = "eventSeq violation: " + IntegerToString((int)prev) + " followed by " + IntegerToString((int)ev.eventSeq);
            return LEDGER_SCAN_SEQ_VIOLATION;
        }
        int n = ArraySize(events);
        ArrayResize(events, n + 1);
        events[n] = ev;
        prev = ev.eventSeq;
    }
    return LEDGER_SCAN_CLEAN;
}

//--- torn-tail recovery (Phase 10): truncate to the last valid record,
//    append a CORRUPTION evidence record, resume contiguously. Refuses
//    every state other than TORN_TAIL (mid-file corruption stays BLOCK).
bool LedgerRecoverTornTail(const string path, string &corruptionInfo)
{
    ExecutionLedgerEvent evs[];
    string info = "";
    if(LedgerScan(path, evs, info) != LEDGER_SCAN_TORN_TAIL)
    {
        corruptionInfo = "recovery refused: ledger is not TORN_TAIL (" + info + ")";
        return false;
    }
    ulong next = (ArraySize(evs) > 0 ? evs[ArraySize(evs) - 1].eventSeq + 1 : 1);

    int h = FileOpen(path, FILE_READ | FILE_TXT | FILE_COMMON);
    if(h == INVALID_HANDLE)
        return false;
    string lines[];
    while(!FileIsEnding(h))
    {
        string ln = FileReadString(h);
        StringTrimRight(ln);
        if(StringLen(ln) == 0)
            continue;
        int n = ArraySize(lines);
        ArrayResize(lines, n + 1);
        lines[n] = ln;
    }
    FileClose(h);
    int last = ArraySize(lines) - 1;

    string tmp = path + ".tmp";
    int ht = FileOpen(tmp, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(ht == INVALID_HANDLE)
        return false;
    for(int i = 0; i < last; i++)
        FileWriteString(ht, lines[i] + "\r\n");
    FileFlush(ht);
    FileClose(ht);
    if(FileIsExist(path, FILE_COMMON))
        FileDelete(path, FILE_COMMON);
    FileMove(tmp, FILE_COMMON, path, FILE_COMMON);

    string corrLine = LedgerBuildRecord(next, "SYSTEM", LEDGER_EVENT_CORRUPTION,
                                        TimeCurrent(), "INTACT", "RECOVERED",
                                        "torn-tail|truncated|" + info);
    int hc = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(hc == INVALID_HANDLE)
        return false;
    FileSeek(hc, 0, SEEK_END);
    FileWriteString(hc, corrLine + "\r\n");
    FileFlush(hc);
    FileClose(hc);
    corruptionInfo = "torn tail truncated at eventSeq " + IntegerToString((int)(next - 1)) + "; CORRUPTION record appended";
    return true;
}

#endif
