//+------------------------------------------------------------------+
//|                                        ConfigFingerprint.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Configuration fingerprint (FNV-1a 64-bit) over every input that can
//  affect decision outcomes or price interpretation:
//
//    confidence threshold | 6 weights | disabled validators (sorted) |
//    symbol | timeframe | ea version | exit policy name@version |
//    slR | tpR | maxHoldBars | spreadMode | brokerDigits |
//    family floors (liquidity | fvg | order block | bos | choch)
//
//  Datasets collected under different configurations can then be
//  partitioned by fingerprint without relying on filenames.
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_CONFIG_FINGERPRINT_MQH__
#define __TELEMETRY_CONFIG_FINGERPRINT_MQH__

#include "TelemetryTypes.mqh"

class CConfigFingerprint
{
public:
    //--- FNV-1a 64-bit over the 16-bit code units of the canonical string.
    static ulong Compute(const string raw)
    {
        ulong hash = 14695981039346656037ULL;   // offset basis
        const ulong prime = 1099511628211ULL;   // FNV prime

        int len = StringLen(raw);
        for(int i = 0; i < len; i++)
        {
            uint c = (uint)StringGetCharacter(raw, i);
            hash ^= (ulong)c;
            hash *= prime;
        }
        return (ulong)hash;
    }

    //--- Sort comma-separated validator names so ordering is canonical.
    static string SortDisabledValidators(const string disabled)
    {
        if(disabled == "")
            return "";

        string parts[];
        int n = StringSplit(disabled, ',', parts);
        for(int i = 0; i < n; i++)
        {
            StringTrimLeft(parts[i]);
            StringTrimRight(parts[i]);
        }

        for(int i = 1; i < n; i++)
        {
            for(int j = i; j > 0; j--)
            {
                if(parts[j - 1] <= parts[j])
                    break;
                string t = parts[j - 1];
                parts[j - 1] = parts[j];
                parts[j] = t;
            }
        }

        string out = "";
        for(int i = 0; i < n; i++)
        {
            if(parts[i] == "")
                continue;
            if(out != "")
                out += ",";
            out += parts[i];
        }
        return out;
    }

    //--- Build the canonical configuration string.
    static string ToCanonical(const CalibrationConfig &cfg,
                              const string symbol,
                              int timeframe,
                              const string policyName,
                              const string policyVersion)
    {
        string canonical = "";
        canonical += DoubleToString(cfg.minConfidence, 6);
        for(int i = 0; i < TELEMETRY_COMPONENT_COUNT; i++)
            canonical += "|" + DoubleToString(cfg.weights[i], 6);
        canonical += "|" + SortDisabledValidators(cfg.disabledValidators);
        canonical += "|" + symbol;
        canonical += "|" + IntegerToString(timeframe);
        canonical += "|" + cfg.eaVersion;
        canonical += "|" + policyName + "@" + policyVersion;
        canonical += "|" + DoubleToString(cfg.slR, 6);
        canonical += "|" + DoubleToString(cfg.tpR, 6);
        canonical += "|" + IntegerToString(cfg.maxHoldBars);
        canonical += "|" + cfg.spreadMode;
        canonical += "|" + IntegerToString(cfg.brokerDigits);
        canonical += "|" + DoubleToString(cfg.familyFloorLiquidity, 6);
        canonical += "|" + DoubleToString(cfg.familyFloorFVG, 6);
        canonical += "|" + DoubleToString(cfg.familyFloorOrderBlock, 6);
        canonical += "|" + DoubleToString(cfg.familyFloorBOS, 6);
        canonical += "|" + DoubleToString(cfg.familyFloorCHOCH, 6);
        canonical += "|" + DoubleToString(cfg.familyFloorUnknown, 6);
        return canonical;
    }

    //--- Full fingerprint for a configuration.
    static ulong Compute(const CalibrationConfig &cfg,
                          const string symbol,
                          int timeframe,
                          const string policyName,
                          const string policyVersion)
    {
        return Compute(ToCanonical(cfg, symbol, timeframe, policyName, policyVersion));
    }

    static string ToHex(ulong fp)
    {
        return StringFormat("%016llX", (ulong)fp);
    }
};

#endif


