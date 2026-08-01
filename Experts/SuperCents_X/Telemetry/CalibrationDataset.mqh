//+------------------------------------------------------------------+
//|                                        CalibrationDataset.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             v2.9.2 (Sprint 14.6)  |
//+------------------------------------------------------------------+
//  Loads telemetry CSV files back into TelemetryRow[] and provides the
//  replay filters used by the calibration optimizers.
//
//  v2.9.2: reads telemetry_v2_*.csv (schemaVersion = 2; all confidence
//  columns 0-1). v1 files predate collection and are not supported.
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_CALIBRATION_DATASET_MQH__
#define __TELEMETRY_CALIBRATION_DATASET_MQH__

#include "../Core/Logger.mqh"
#include "TelemetryTypes.mqh"

#define TELEMETRY_CSV_COLUMNS 45

class CCalibrationDataset
{
private:
    CLogger      m_logger;
    TelemetryRow m_rows[];
    int          m_count;
    int          m_scannedFiles;
    int          m_skippedRows;

    static bool ParseRow(const string line, TelemetryRow &out)
    {
        string col[];
        int n = StringSplit(line, ',', col);
        if(n != TELEMETRY_CSV_COLUMNS)
            return false;

        int i = 0;
        int schemaVersion = (int)StringToInteger(col[i++]);
        if(schemaVersion != TELEMETRY_SCHEMA_VERSION)
            return false;

        out = TelemetryRow();
        out.schemaVersion = (uint)schemaVersion;
        out.configFingerprint = (ulong)StringToInteger(col[i++]);
        out.timestamp = StringToTime(col[i++]);
        out.symbol = col[i++];
        out.timeframe = (int)StringToInteger(col[i++]);
        out.eaVersion = col[i++];
        out.decisionId = (int)StringToInteger(col[i++]);
        out.direction = (int)StringToInteger(col[i++]);
        out.confidence = StringToDouble(col[i++]);
        out.structureRaw = StringToDouble(col[i++]); out.structureWeight = StringToDouble(col[i++]); out.structureContribution = StringToDouble(col[i++]);
        out.obRaw = StringToDouble(col[i++]);        out.obWeight = StringToDouble(col[i++]);        out.obContribution = StringToDouble(col[i++]);
        out.fvgRaw = StringToDouble(col[i++]);       out.fvgWeight = StringToDouble(col[i++]);       out.fvgContribution = StringToDouble(col[i++]);
        out.trendRaw = StringToDouble(col[i++]);     out.trendWeight = StringToDouble(col[i++]);     out.trendContribution = StringToDouble(col[i++]);
        out.liquidityRaw = StringToDouble(col[i++]); out.liquidityWeight = StringToDouble(col[i++]); out.liquidityContribution = StringToDouble(col[i++]);
        out.pdRaw = StringToDouble(col[i++]);        out.pdWeight = StringToDouble(col[i++]);        out.pdContribution = StringToDouble(col[i++]);
        out.UnpackValidatorResults(col[i++]);
        out.confThreshold = StringToDouble(col[i++]);
        out.newDecision = (StringToInteger(col[i++]) != 0);
        out.legacyDecision = (StringToInteger(col[i++]) != 0);
        out.decisionMatch = (StringToInteger(col[i++]) != 0);
        out.directionMatch = (StringToInteger(col[i++]) != 0);
        out.legacyConfidence = StringToDouble(col[i++]);
        out.newConfidence = StringToDouble(col[i++]);
        out.disabledValidators = FromPipedList(col[i++]);
        out.outcomeSource = (int)StringToInteger(col[i++]);
        out.outcome = (int)StringToInteger(col[i++]);
        out.rMultiple = StringToDouble(col[i++]);
        out.barsHeld = (int)StringToInteger(col[i++]);
        out.exitReason = (int)StringToInteger(col[i++]);
        out.entryPrice = StringToDouble(col[i++]);
        out.exitPrice = StringToDouble(col[i++]);
        out.actualOutcome = (int)StringToInteger(col[i++]);
        out.actualOutcomeSource = (int)StringToInteger(col[i++]);
        return true;
    }

    static string FromPipedList(const string piped)
    {
        if(piped == "")
            return "";
        string parts[];
        int n = StringSplit(piped, '|', parts);
        string out = "";
        for(int i = 0; i < n; i++)
        {
            if(out != "")
                out += ",";
            out += parts[i];
        }
        return out;
    }

    static bool IsBlankLine(const string line)
    {
        string t = line;
        StringTrimLeft(t);
        StringTrimRight(t);
        return t == "";
    }

    bool AppendFile(const string filepath)
    {
        int handle = FileOpen(filepath, FILE_READ | FILE_TXT | FILE_COMMON);
        if(handle == INVALID_HANDLE)
            return false;

        bool first = true;
        int added = 0;
        int skipped = 0;

        while(!FileIsEnding(handle))
        {
            string line = FileReadString(handle);
            if(first)
            {
                first = false;
                if(StringFind(line, "schemaVersion") == 0)
                    continue;
            }
            if(IsBlankLine(line))
                continue;

            TelemetryRow row;
            if(ParseRow(line, row))
            {
                int idx = m_count;
                ArrayResize(m_rows, idx + 1);
                m_rows[idx] = row;
                m_count++;
                added++;
            }
            else
            {
                skipped++;
            }
        }
        FileClose(handle);

        m_scannedFiles++;
        m_skippedRows += skipped;
        m_logger.LogInfo(StringFormat("Telemetry: loaded %d rows from %s (skipped %d)",
                                      added, filepath, skipped));
        return added > 0;
    }

public:
    CCalibrationDataset(void)
        : m_logger(MODULE_UNKNOWN, "CalibrationDataset")
        , m_count(0)
        , m_scannedFiles(0)
        , m_skippedRows(0)
    {}

    void Clear(void)
    {
        ArrayFree(m_rows);
        m_count = 0;
        m_scannedFiles = 0;
        m_skippedRows = 0;
    }

    bool LoadFile(const string filepath)
    {
        return AppendFile(filepath);
    }

    //--- Load every telemetry CSV in the directory matching the pattern.
    int LoadDir(const string outputDir, const string pattern = "telemetry_v2_*.csv")
    {
        string filter = outputDir;
        int fl = StringLen(filter);
        if(fl == 0 || (StringSubstr(filter, fl - 1) != "/" && StringSubstr(filter, fl - 1) != "\\"))
            filter += "\\";
        filter += pattern;

        string filename;
        int handle = (int)FileFindFirst(filter, filename, FILE_COMMON);
        if(handle == INVALID_HANDLE)
        {
            m_logger.LogWarn("Telemetry: no files match " + filter);
            return 0;
        }

        int loaded = 0;
        do
        {
            string fullPath = outputDir;
            int pl = StringLen(fullPath);
            if(pl == 0 || (StringSubstr(fullPath, pl - 1) != "/" && StringSubstr(fullPath, pl - 1) != "\\"))
                fullPath += "\\";
            fullPath += filename;
            if(AppendFile(fullPath))
                loaded++;
        }
        while(FileFindNext(handle, filename));
        FileFindClose(handle);

        return loaded;
    }

    bool FilterByFingerprint(ulong fp, CCalibrationDataset &out) const
    {
        out.Clear();
        for(int i = 0; i < m_count; i++)
        {
            if(m_rows[i].configFingerprint != fp)
                continue;
            int idx = out.m_count;
            ArrayResize(out.m_rows, idx + 1);
            out.m_rows[idx] = m_rows[i];
            out.m_count++;
        }
        return out.m_count > 0;
    }

    bool FilterRange(datetime from, datetime to, CCalibrationDataset &out) const
    {
        out.Clear();
        for(int i = 0; i < m_count; i++)
        {
            if(m_rows[i].timestamp < from || m_rows[i].timestamp > to)
                continue;
            int idx = out.m_count;
            ArrayResize(out.m_rows, idx + 1);
            out.m_rows[idx] = m_rows[i];
            out.m_count++;
        }
        return out.m_count > 0;
    }

    int GetCount(void) const { return m_count; }
    int GetScannedFiles(void) const { return m_scannedFiles; }
    int GetSkippedRows(void) const { return m_skippedRows; }

    bool GetRow(int index, TelemetryRow &out) const
    {
        if(index < 0 || index >= m_count)
            return false;
        out = m_rows[index];
        return true;
    }
};

#endif

