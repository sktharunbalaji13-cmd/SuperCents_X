//+------------------------------------------------------------------+
//|                                           PositionSizer.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __RISK_POSITION_SIZER_MQH__
#define __RISK_POSITION_SIZER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "RiskTypes.mqh"

class CPositionSizer
{
private:
    CLogger m_logger;
    bool    m_isInitialized;
    string  m_symbol;

    double  m_tickValue;
    double  m_tickSize;
    double  m_point;
    double  m_volumeMin;
    double  m_volumeMax;
    double  m_volumeStep;
    double  m_contractSize;

    void RefreshSymbolProperties(void)
    {
        m_tickValue    = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
        m_tickSize     = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
        m_point        = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        m_volumeMin    = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
        m_volumeMax    = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
        m_volumeStep   = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
        m_contractSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    }

public:
    CPositionSizer(void);
    ~CPositionSizer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetSymbol(string symbol);

    string GetSymbol(void) const { return m_symbol; }
    double GetVolumeMin(void) const { return m_volumeMin; }
    double GetVolumeMax(void) const { return m_volumeMax; }

    PositionSizingResult Calculate(
        double riskPercent,
        double stopDistancePoints,
        double accountEquity,
        double tickValue,
        double tickSize,
        double point,
        double volumeMin,
        double volumeMax,
        double volumeStep
    );

    PositionSizingResult CalculateCached(
        double riskPercent,
        double stopDistancePoints,
        double accountEquity
    );
};

CPositionSizer::CPositionSizer(void)
    : m_logger(MODULE_POSITION_SIZER, "PositionSizer")
    , m_isInitialized(false)
    , m_symbol(_Symbol)
    , m_tickValue(0.0)
    , m_tickSize(0.0)
    , m_point(0.00001)
    , m_volumeMin(0.01)
    , m_volumeMax(100.0)
    , m_volumeStep(0.01)
    , m_contractSize(100000.0)
{
}

CPositionSizer::~CPositionSizer(void)
{
    Shutdown();
}

bool CPositionSizer::Init(void)
{
    m_logger.LogInfo("Initializing PositionSizer...");
    RefreshSymbolProperties();
    m_isInitialized = true;
    m_logger.LogInfo("PositionSizer initialized");
    return true;
}

void CPositionSizer::Update(void)
{
    //--- P37 (integrity, Fix 6): refresh cached contract spec. Tick value
    //    drifts with price on cross pairs; a stale cache silently mis-sizes.
    if(m_isInitialized)
        RefreshSymbolProperties();
}

void CPositionSizer::Shutdown(void)
{
    m_logger.LogInfo("Shutting down PositionSizer...");
    m_isInitialized = false;
    m_logger.LogInfo("PositionSizer shutdown complete");
}

void CPositionSizer::SetSymbol(string symbol)
{
    if(m_symbol != symbol)
    {
        m_symbol = symbol;
        if(m_isInitialized)
            RefreshSymbolProperties();
    }
}

PositionSizingResult CPositionSizer::Calculate(
    double riskPercent,
    double stopDistancePoints,
    double accountEquity,
    double tickValue,
    double tickSize,
    double point,
    double volumeMin,
    double volumeMax,
    double volumeStep)
{
    PositionSizingResult result;

    if(riskPercent <= 0.0)
    {
        result.validationMessage = "Risk percent must be positive";
        return result;
    }

    if(stopDistancePoints <= 0.0)
    {
        result.validationMessage = "Stop distance must be positive";
        return result;
    }

    if(accountEquity <= 0.0)
    {
        result.validationMessage = "Account equity must be positive";
        return result;
    }

    if(tickValue <= 0.0 || tickSize <= 0.0 || point <= 0.0)
    {
        result.validationMessage = "Invalid symbol properties (tickValue, tickSize, point)";
        return result;
    }

    if(volumeStep <= 0.0 || volumeMin <= 0.0 || volumeMax <= 0.0)
    {
        result.validationMessage = "Invalid volume constraints";
        return result;
    }

    double riskMoney = accountEquity * (riskPercent / 100.0);

    double riskPerLot = (stopDistancePoints * tickValue) / (tickSize / point);

    if(riskPerLot <= 0.0)
    {
        result.validationMessage = "Risk per lot calculation yielded zero or negative";
        return result;
    }

    double lots = riskMoney / riskPerLot;
    if(volumeStep > 0.0)
        lots = MathFloor(lots / volumeStep) * volumeStep;

    //--- P37 (integrity, Fix 6): reject instead of silently floor-clamping.
    //    Clamping lots UP to volumeMin risked MORE dollars than configured
    //    (tight stop or small equity). Callers must treat invalid as reject,
    //    never as fallback-to-fixed-lot. Ceiling clamp (over max) only ever
    //    under-risks, so it is retained.
    if(lots < volumeMin)
    {
        result.validationMessage = StringFormat(
            "POSITION-SIZING-REJECTED computed lots=%.4f below broker minimum=%.2f (stop too tight for min lot at this risk%%)",
            lots, volumeMin);
        return result;
    }

    if(lots > volumeMax)
        lots = volumeMax;

    result.lots = lots;
    result.dollarRisk = lots * riskPerLot;
    result.valid = true;
    result.validationMessage = StringFormat("POSITION-SIZED lots=%.2f risk=$%.2f stop=%.0fpts",
        lots, result.dollarRisk, stopDistancePoints);

    return result;
}

PositionSizingResult CPositionSizer::CalculateCached(
    double riskPercent,
    double stopDistancePoints,
    double accountEquity)
{
    return Calculate(
        riskPercent,
        stopDistancePoints,
        accountEquity,
        m_tickValue,
        m_tickSize,
        m_point,
        m_volumeMin,
        m_volumeMax,
        m_volumeStep
    );
}

#endif
