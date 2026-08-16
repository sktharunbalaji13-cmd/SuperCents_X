//+------------------------------------------------------------------+
//|                                                   Config.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __CONFIG_MQH__
#define __CONFIG_MQH__

#include "../Utils/Constants.mqh"
#include "../Entry/EntryConfig.mqh"
#include "../Telemetry/IOutcomePolicy.mqh"

class CConfig
{
private:
    bool            m_isInitialized;
    bool            m_loggingEnabled;
    string          m_eaName;
    int             m_magicNumber;
    int             m_slippage;
    //--- C2 (integrity): risk % of equity per trade and the per-symbol
    //    position cap consumed by the TradeManager execution path.
    double          m_riskPercent;
    int             m_maxPositionsPerSymbol;
    ENUM_ENTRY_MODE m_entryMode;
    ENUM_OUTCOME_TP_MODE m_outcomeTpMode;
    double m_fixedRrTier;
    //--- Sprint 22 (RL-HYP-01): swing-significance admission gate tier.
    //    Default 0.0 = gate OFF (B8 behavior); tier values are the k in
    //    amplitude >= k * ATR(14) (§5). Lives OUTSIDE the configuration
    //    fingerprint (§11.1, ED01-E hardcoded-token precedent).
    double m_swingSignificanceTier;

public:
    CConfig(void);
    bool Init(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    //--- Getters
    bool IsLoggingEnabled(void) const { return m_loggingEnabled; }
    string GetEAName(void) const { return m_eaName; }
    int GetMagicNumber(void) const { return m_magicNumber; }
    int GetSlippage(void) const { return m_slippage; }
    double GetRiskPercent(void) const { return m_riskPercent; }
    int GetMaxPositionsPerSymbol(void) const { return m_maxPositionsPerSymbol; }
    ENUM_ENTRY_MODE GetEntryMode(void) const { return m_entryMode; }
    ENUM_OUTCOME_TP_MODE GetOutcomeTpMode(void) const { return m_outcomeTpMode; }
    //--- ED01-E prerequisite: fixed-RR TP tier (R-multiple). Default 2.0R
    //    keeps the B8 settle-time behavior; the tier sweep overrides it.
    double GetFixedRrTier(void) const { return m_fixedRrTier; }
    double GetSwingSignificanceTier(void) const { return m_swingSignificanceTier; }

    //--- Setters
    void SetLoggingEnabled(bool enabled) { m_loggingEnabled = enabled; }
    void SetMagicNumber(int magic) { m_magicNumber = magic; }
    void SetRiskPercent(double pct) { m_riskPercent = fmax(pct, 0.0); }
    void SetMaxPositionsPerSymbol(int max) { m_maxPositionsPerSymbol = MathMax(max, 1); }
    void SetEntryMode(ENUM_ENTRY_MODE mode) { m_entryMode = mode; }
    void SetOutcomeTpMode(ENUM_OUTCOME_TP_MODE mode) { m_outcomeTpMode = mode; }
    void SetFixedRrTier(double tier) { m_fixedRrTier = tier; }
    void SetSwingSignificanceTier(double tier) { m_swingSignificanceTier = tier; }
};

//--- Inline implementation
CConfig::CConfig(void) : m_isInitialized(false), m_loggingEnabled(true), m_eaName("SuperCents_X"), m_magicNumber(0), m_slippage(3), m_riskPercent(1.0), m_maxPositionsPerSymbol(1), m_entryMode(ENTRY_MODE_LEGACY), m_outcomeTpMode(OUTCOME_TP_FIXED_RR), m_fixedRrTier(2.0), m_swingSignificanceTier(0.0) {}

bool CConfig::Init(void)
{
    m_isInitialized = true;
    //--- C1 (integrity): the magic number is set explicitly by the EA
    //    input BEFORE Init via SetMagicNumber.  The previous
    //    (int)TimeCurrent() derivation made the order identity change
    //    on every restart (orphaning open positions and the
    //    IsAlreadySubmitted dedup ledger).
    m_slippage = 3;
    return true;
}

#endif // __CONFIG_MQH__