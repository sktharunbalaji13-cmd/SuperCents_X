//+------------------------------------------------------------------+
//|                                        TelemetryCollector.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             v2.9.2 (Sprint 14.6)  |
//+------------------------------------------------------------------+
//  Persists every decision as one CSV row (frozen v2 schema).
//
//  - Daily rotation: telemetry_v2_YYYYMMDD.csv under Common\Files\Telemetry
//    (FILE_COMMON is used on write AND read sides — CalibrationDataset)
//  - Header written only when the file is created
//  - Rows buffered in memory and flushed on demand / when full
//  - decisionId is assigned run-locally when the caller passes 0
//
//  Serialization notes:
//  - validatorResults:   "Name=0|Name=2" (no commas inside)
//  - disabledValidators: pipe-joined (commas would break CSV columns);
//    parsed back to the canonical comma-separated form
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_COLLECTOR_MQH__
#define __TELEMETRY_COLLECTOR_MQH__

#include "../Core/Logger.mqh"
#include "TelemetryTypes.mqh"

#define TELEMETRY_BUFFER_CAPACITY 1024

class CTelemetryCollector
{
private:
    CLogger m_logger;
    bool    m_isInitialized;
    bool    m_enabled;

    string  m_outputDir;
    TelemetryRow m_rows[];
    int     m_buffered;
    int     m_totalRows;
    int     m_faultCount;
    int     m_runId;

    string BuildFilePath(void) const
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        return StringFormat("%s/telemetry_v%d_%04d%02d%02d.csv",
                            m_outputDir,
                            TELEMETRY_SCHEMA_VERSION,
                            dt.year, dt.mon, dt.day);
    }

    bool WriteHeader(int handle)
    {
        return FileWrite(handle, TELEMETRY_CSV_HEADER_V2) > 0;
    }

    bool WriteRow(int handle, const TelemetryRow &row)
    {
        string line = StringFormat(
            "%d,%llu,%s,%s,%d,%s,%d,%d,%.8f,"
            "%.8f,%.6f,%.8f,%.8f,%.6f,%.8f,%.8f,%.6f,%.8f,"
            "%.8f,%.6f,%.8f,%.8f,%.6f,%.8f,%.8f,%.6f,%.8f,"
            "%s,%.6f,%d,%d,%d,%d,%.8f,%.8f,%s,"
            "%d,%d,%.8f,%d,%d,%.8f,%.8f,"
            "%d,%d",
            (int)row.schemaVersion,
            (ulong)row.configFingerprint,
            TimeToString(row.timestamp),
            row.symbol,
            row.timeframe,
            row.eaVersion,
            row.decisionId,
            row.direction,
            row.confidence,
            row.structureRaw, row.structureWeight, row.structureContribution,
            row.obRaw,        row.obWeight,        row.obContribution,
            row.fvgRaw,       row.fvgWeight,       row.fvgContribution,
            row.trendRaw,     row.trendWeight,     row.trendContribution,
            row.liquidityRaw, row.liquidityWeight, row.liquidityContribution,
            row.pdRaw,        row.pdWeight,        row.pdContribution,
            row.PackValidatorResults(),
            row.confThreshold,
            (row.newDecision ? 1 : 0),
            (row.legacyDecision ? 1 : 0),
            (row.decisionMatch ? 1 : 0),
            (row.directionMatch ? 1 : 0),
            row.legacyConfidence,
            row.newConfidence,
            ToPipedList(row.disabledValidators),
            row.outcomeSource,
            row.outcome,
            row.rMultiple,
            row.barsHeld,
            row.exitReason,
            row.entryPrice,
            row.exitPrice,
            row.actualOutcome,
            row.actualOutcomeSource);
        return FileWrite(handle, line) > 0;
    }

    bool FlushBuffer(void)
    {
        if(m_buffered == 0)
            return true;

        string filePath = BuildFilePath();
        bool exists = FileIsExist(filePath, FILE_COMMON);
        int handle = FileOpen(filePath, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
        if(handle == INVALID_HANDLE)
        {
            m_faultCount++;
            m_logger.LogError("Telemetry: failed to open " + filePath);
            return false;
        }

        bool ok = true;
        if(!exists || FileSize(handle) == 0)
        {
            if(!WriteHeader(handle))
            {
                m_faultCount++;
                ok = false;
            }
        }

        if(ok && FileSeek(handle, 0, SEEK_END))
        {
            for(int i = 0; i < m_buffered; i++)
            {
                if(!WriteRow(handle, m_rows[i]))
                {
                    m_faultCount++;
                    ok = false;
                    break;
                }
            }
        }
        else if(ok)
        {
            m_faultCount++;
            ok = false;
        }

        FileClose(handle);

        if(ok)
        {
            m_totalRows += m_buffered;
            m_buffered = 0;
        }
        return ok;
    }

    static string ToPipedList(const string commaList)
    {
        if(commaList == "")
            return "";
        string parts[];
        int n = StringSplit(commaList, ',', parts);
        string out = "";
        for(int i = 0; i < n; i++)
        {
            string t = parts[i];
            StringTrimLeft(t);
            StringTrimRight(t);
            if(t == "")
                continue;
            if(out != "")
                out += "|";
            out += t;
        }
        return out;
    }

public:
    CTelemetryCollector(void)
        : m_logger(MODULE_UNKNOWN, "Telemetry")
        , m_isInitialized(false)
        , m_enabled(true)
        , m_outputDir("Telemetry")
        , m_buffered(0)
        , m_totalRows(0)
        , m_faultCount(0)
        , m_runId(0)
    {}

    bool Init(const string outputDir = "Telemetry")
    {
        m_outputDir = outputDir;
        m_buffered = 0;
        m_totalRows = 0;
        m_faultCount = 0;
        m_runId = 0;
        m_isInitialized = true;
        m_logger.LogInfo("Telemetry collector initialized (schema v" + IntegerToString(TELEMETRY_SCHEMA_VERSION) + ", "
                         + BuildFilePath() + ")");
        return true;
    }

    void SetEnabled(bool enabled) { m_enabled = enabled; }

    bool Record(TelemetryRow &row)
    {
        if(!m_isInitialized || !m_enabled)
            return false;

        if(row.decisionId == 0)
            row.decisionId = ++m_runId;

        int idx = m_buffered;
        if(idx >= ArraySize(m_rows))
            ArrayResize(m_rows, ArraySize(m_rows) + 256);
        if(idx >= TELEMETRY_BUFFER_CAPACITY)
        {
            if(!FlushBuffer())
                return false;
            idx = 0;
        }
        m_rows[idx] = row;
        m_buffered++;
        return true;
    }

    bool Flush(void) { return FlushBuffer(); }

    void Shutdown(void)
    {
        FlushBuffer();
        if(m_totalRows > 0)
        {
            m_logger.LogInfo("========================== TELEMETRY SUMMARY ==========================");
            m_logger.LogInfo(StringFormat("  %-35s %5d", "Rows Written",      m_totalRows));
            m_logger.LogInfo(StringFormat("  %-35s %5d", "I/O Faults",        m_faultCount));
            m_logger.LogInfo(StringFormat("  %-35s %s",  "Output",            BuildFilePath()));
            m_logger.LogInfo("======================================================================");
        }
        m_isInitialized = false;
    }

    int  GetTotalRows(void) const { return m_totalRows; }
    int  GetFaultCount(void) const { return m_faultCount; }
    bool IsEnabled(void) const { return m_enabled; }
};

#endif

