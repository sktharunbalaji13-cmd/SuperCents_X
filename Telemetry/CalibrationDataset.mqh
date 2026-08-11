//+------------------------------------------------------------------+
//|                                        CalibrationDataset.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             v3.1 (Sprint 17)       |
//+------------------------------------------------------------------+
//  Loads telemetry CSV files back into TelemetryRow[] and provides the
//  replay filters used by the calibration optimizers.
//
//  v2.9.2: reads telemetry_v2_*.csv (schemaVersion = 2; all confidence
//  columns 0-1). v1 files predate collection and are not supported.
//  v3.1: reads telemetry_v3_*.csv (schemaVersion = 3; 68 columns with
//  rule/layer/evidence observations) AND still parses v2 files (45
//  columns). Rows carry their own schemaVersion; consumers that need
//  component evidence (structural diagnostics) must refuse v2 rows.
//  Sprint 20 TC01: reads v4 (schemaVersion = 4; 75 columns = v3 + the
//  7 split-layer/FVG-classifier columns) while v2/v3 rows still parse.
//  Sprint 22 RL-HYP-01: reads v5 (schemaVersion = 5; 78 columns = v3.1
//  + the 3 swing-gate columns) while v2/v3/v4 rows still parse.
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_CALIBRATION_DATASET_MQH__
#define __TELEMETRY_CALIBRATION_DATASET_MQH__

#include "../Core/Logger.mqh"
#include "TelemetryTypes.mqh"

#define TELEMETRY_CSV_COLUMNS     45
#define TELEMETRY_CSV_COLUMNS_V3  68
#define TELEMETRY_CSV_COLUMNS_V31 75
#define TELEMETRY_CSV_COLUMNS_V5  78

class CCalibrationDataset
{
private:
    CLogger      m_logger;
    TelemetryRow m_rows[];
    int          m_count;
    int          m_scannedFiles;
    int          m_skippedRows;

public:
    //--- Parse an unsigned decimal fingerprint. StringToInteger returns a
    //    signed long and SATURATES at INT64_MAX (0x7FFFFFFFFFFFFFFF) for
    //    values above it — a real fingerprint > INT64_MAX would silently
    //    collapse into one phantom set. Chunked parsing keeps full ulong
    //    range (verified by TestCalibrationDataset).
    static ulong ParseUnsigned(const string s)
    {
        int len = StringLen(s);
        if(len == 0)
            return 0;
        if(len <= 9)
            return (ulong)StringToInteger(s);

        string hi = StringSubstr(s, 0, len - 9);
        string lo = StringSubstr(s, len - 9, 9);
        return (ulong)StringToInteger(hi) * (ulong)1000000000
               + (ulong)StringToInteger(lo);
    }

public:
    //--- Parse one CSV line into a TelemetryRow. Schema-version aware:
    //    v2 lines (45 columns), v3 lines (68 columns), v3.1 lines (75
    //    columns) and v5 lines (78 columns) are accepted; any other
    //    schemaVersion or a column-count mismatch is refused explicitly
    //    (no silent reinterpretation of old datasets).
    static bool ParseRow(const string line, TelemetryRow &out)
    {
        string col[];
        int n = StringSplit(line, ',', col);

        //--- Rejoin quoted fields: ruleEvidenceIds is packed "1,4" and is
        //    written quoted (CSV), so a plain split would misalign columns.
        string fld[];
        int m = MergeQuotedFields(col, n, fld);
        if(m != TELEMETRY_CSV_COLUMNS && m != TELEMETRY_CSV_COLUMNS_V3
                && m != TELEMETRY_CSV_COLUMNS_V31 && m != TELEMETRY_CSV_COLUMNS_V5)
            return false;

        int i = 0;
        int schemaVersion = (int)StringToInteger(fld[i++]);
        if(schemaVersion != 2 && schemaVersion != 3 && schemaVersion != 4 && schemaVersion != 5)
            return false;
        if(schemaVersion == 2 && m != TELEMETRY_CSV_COLUMNS)
            return false;
        if(schemaVersion == 3 && m != TELEMETRY_CSV_COLUMNS_V3)
            return false;
        if(schemaVersion == 4 && m != TELEMETRY_CSV_COLUMNS_V31)
            return false;
        if(schemaVersion == 5 && m != TELEMETRY_CSV_COLUMNS_V5)
            return false;

        out = TelemetryRow();
        out.schemaVersion = (uint)schemaVersion;
        out.configFingerprint = ParseUnsigned(fld[i++]);
        out.timestamp = StringToTime(fld[i++]);
        out.symbol = fld[i++];
        out.timeframe = (int)StringToInteger(fld[i++]);
        out.eaVersion = fld[i++];
        out.decisionId = (int)StringToInteger(fld[i++]);
        out.direction = (int)StringToInteger(fld[i++]);
        out.confidence = StringToDouble(fld[i++]);
        out.structureRaw = StringToDouble(fld[i++]); out.structureWeight = StringToDouble(fld[i++]); out.structureContribution = StringToDouble(fld[i++]);
        out.obRaw = StringToDouble(fld[i++]);        out.obWeight = StringToDouble(fld[i++]);        out.obContribution = StringToDouble(fld[i++]);
        out.fvgRaw = StringToDouble(fld[i++]);       out.fvgWeight = StringToDouble(fld[i++]);       out.fvgContribution = StringToDouble(fld[i++]);
        out.trendRaw = StringToDouble(fld[i++]);     out.trendWeight = StringToDouble(fld[i++]);     out.trendContribution = StringToDouble(fld[i++]);
        out.liquidityRaw = StringToDouble(fld[i++]); out.liquidityWeight = StringToDouble(fld[i++]); out.liquidityContribution = StringToDouble(fld[i++]);
        out.pdRaw = StringToDouble(fld[i++]);        out.pdWeight = StringToDouble(fld[i++]);        out.pdContribution = StringToDouble(fld[i++]);
        out.UnpackValidatorResults(fld[i++]);
        out.confThreshold = StringToDouble(fld[i++]);
        out.newDecision = (StringToInteger(fld[i++]) != 0);
        out.legacyDecision = (StringToInteger(fld[i++]) != 0);
        out.decisionMatch = (StringToInteger(fld[i++]) != 0);
        out.directionMatch = (StringToInteger(fld[i++]) != 0);
        out.legacyConfidence = StringToDouble(fld[i++]);
        out.newConfidence = StringToDouble(fld[i++]);
        out.disabledValidators = FromPipedList(fld[i++]);
        out.outcomeSource = (int)StringToInteger(fld[i++]);
        out.outcome = (int)StringToInteger(fld[i++]);
        out.rMultiple = StringToDouble(fld[i++]);
        out.barsHeld = (int)StringToInteger(fld[i++]);
        out.exitReason = (int)StringToInteger(fld[i++]);
        out.entryPrice = StringToDouble(fld[i++]);
        out.exitPrice = StringToDouble(fld[i++]);
        out.actualOutcome = (int)StringToInteger(fld[i++]);
        out.actualOutcomeSource = (int)StringToInteger(fld[i++]);

        //--- Schema v3 evidence columns (append-only over v2).
        if(schemaVersion == 3)
        {
            out.scoreArchitecture = fld[i++];
            out.telemetryArchitecture = fld[i++];
            out.evidenceContract = fld[i++];
            out.confidenceModel = fld[i++];
            out.componentData = (int)StringToInteger(fld[i++]);
            out.firedRuleId = (int)StringToInteger(fld[i++]);
            out.ruleName = fld[i++];
            out.ruleScore = (int)StringToInteger(fld[i++]);
            out.ruleConfidence = StringToDouble(fld[i++]);
            out.ruleEvidenceCount = (int)StringToInteger(fld[i++]);
            out.ruleEvidenceIds = fld[i++];
            out.trendAligned = (int)StringToInteger(fld[i++]);
            out.layerStructural = (int)StringToInteger(fld[i++]);
            out.layerLiquidity = (int)StringToInteger(fld[i++]);
            out.layerConfirmation = (int)StringToInteger(fld[i++]);
            out.layerTotal = (int)StringToInteger(fld[i++]);
            out.hasBOS = (int)StringToInteger(fld[i++]);
            out.hasCHOCH = (int)StringToInteger(fld[i++]);
            out.hasOrderBlock = (int)StringToInteger(fld[i++]);
            out.hasFVG = (int)StringToInteger(fld[i++]);
            out.hasProtectedPoint = (int)StringToInteger(fld[i++]);
            out.hasLiquiditySweep = (int)StringToInteger(fld[i++]);
            out.signalTime = StringToTime(fld[i++]);
        }

        //--- Schema v3.1 evidence columns (Sprint 20 TC01; v4/v5 rows
        //    carry the 7 appended columns; strictly append-only over v3).
        if(schemaVersion == 4 || schemaVersion == 5)
        {
            out.scoreArchitecture = fld[i++];
            out.telemetryArchitecture = fld[i++];
            out.evidenceContract = fld[i++];
            out.confidenceModel = fld[i++];
            out.componentData = (int)StringToInteger(fld[i++]);
            out.firedRuleId = (int)StringToInteger(fld[i++]);
            out.ruleName = fld[i++];
            out.ruleScore = (int)StringToInteger(fld[i++]);
            out.ruleConfidence = StringToDouble(fld[i++]);
            out.ruleEvidenceCount = (int)StringToInteger(fld[i++]);
            out.ruleEvidenceIds = fld[i++];
            out.trendAligned = (int)StringToInteger(fld[i++]);
            out.layerStructural = (int)StringToInteger(fld[i++]);
            out.layerLiquidity = (int)StringToInteger(fld[i++]);
            out.layerConfirmation = (int)StringToInteger(fld[i++]);
            out.layerTotal = (int)StringToInteger(fld[i++]);
            out.hasBOS = (int)StringToInteger(fld[i++]);
            out.hasCHOCH = (int)StringToInteger(fld[i++]);
            out.hasOrderBlock = (int)StringToInteger(fld[i++]);
            out.hasFVG = (int)StringToInteger(fld[i++]);
            out.hasProtectedPoint = (int)StringToInteger(fld[i++]);
            out.hasLiquiditySweep = (int)StringToInteger(fld[i++]);
            out.signalTime = StringToTime(fld[i++]);
            out.layerOrderBlock = (int)StringToInteger(fld[i++]);
            out.layerFVG = (int)StringToInteger(fld[i++]);
            out.fvgClass = fld[i++];
            out.fvgSize = fld[i++];
            out.fvgStrength = fld[i++];
            out.fvgCreatedTime = StringToTime(fld[i++]);
            out.fvgFillTime = StringToTime(fld[i++]);
        }

        //--- Schema v5 swing-gate columns (Sprint 22 RL-HYP-01; v5 rows
        //    carry the 3 appended columns; strictly append-only over v3.1).
        if(schemaVersion == 5)
        {
            out.swingQualifyingId = (int)StringToInteger(fld[i++]);
            out.swingAmplitude = StringToDouble(fld[i++]);
            out.gateDecision = fld[i++];
        }
        return true;
    }

    //--- Rebuild CSV fields after a naive comma split: any field that was
    //    quoted (starts with ") is joined back together, dropping the quotes.
    static int MergeQuotedFields(const string &col[], const int n, string &out[])
    {
        ArrayResize(out, 0);
        for(int k = 0; k < n; k++)
        {
            string tok = col[k];
            if(StringFind(tok, "\"") == 0)
            {
                string cleaned = StringSubstr(tok, 1);
                if(StringFind(cleaned, "\"") == StringLen(cleaned) - 1 || StringLen(cleaned) == 0)
                {
                    if(StringLen(cleaned) > 0)
                        cleaned = StringSubstr(cleaned, 0, StringLen(cleaned) - 1);
                    int s = ArraySize(out);
                    ArrayResize(out, s + 1);
                    out[s] = cleaned;
                    continue;
                }
                k++;
                while(k < n)
                {
                    string part = col[k];
                    if(StringFind(part, "\"") == StringLen(part) - 1)
                    {
                        cleaned += "," + StringSubstr(part, 0, StringLen(part) - 1);
                        break;
                    }
                    cleaned += "," + part;
                    k++;
                }
                int s = ArraySize(out);
                ArrayResize(out, s + 1);
                out[s] = cleaned;
            }
            else
            {
                int s = ArraySize(out);
                ArrayResize(out, s + 1);
                out[s] = tok;
            }
        }
        return ArraySize(out);
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

    //--- Load every telemetry CSV in the directory matching the pattern
    //    (default covers both telemetry_v2_* and telemetry_v3_* files;
    //    each row carries its own schemaVersion).
    int LoadDir(const string outputDir, const string pattern = "telemetry_v*.csv")
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

