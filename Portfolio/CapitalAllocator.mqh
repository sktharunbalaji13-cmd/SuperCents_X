//+------------------------------------------------------------------+
//|                                          CapitalAllocator.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_CAPITAL_ALLOCATOR_MQH__
#define __PORTFOLIO_CAPITAL_ALLOCATOR_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PortfolioRiskTypes.mqh"

enum ENUM_ALLOCATION_POLICY
{
    ALLOC_FIXED_PERCENT = 0,
    ALLOC_FIXED_LOT,
    ALLOC_VOLATILITY_SCALED,
    ALLOC_EQUAL_RISK,
    ALLOC_POLICY_COUNT
};

class CAllocationEngine;

class CCapitalAllocator
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    ENUM_ALLOCATION_POLICY m_policy;
    double                 m_fixedPercent;
    double                 m_fixedLots;

public:
    CCapitalAllocator(void);
    ~CCapitalAllocator(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetPolicy(ENUM_ALLOCATION_POLICY policy) { m_policy = policy; }
    void SetFixedPercent(double pct) { m_fixedPercent = pct; }
    void SetFixedLots(double lots) { m_fixedLots = lots; }

    ENUM_ALLOCATION_POLICY GetPolicy(void) const { return m_policy; }

    double CalculateSize(const AllocationRequest &request, const PortfolioExposure &exposure) const;
    string PolicyName(void) const;
};

CCapitalAllocator::CCapitalAllocator(void)
    : m_logger(MODULE_CAPITAL_ALLOCATOR, "CapitalAllocator")
    , m_isInitialized(false)
    , m_policy(ALLOC_FIXED_PERCENT)
    , m_fixedPercent(2.0)
    , m_fixedLots(0.01)
{
}

CCapitalAllocator::~CCapitalAllocator(void)
{
    Shutdown();
}

bool CCapitalAllocator::Init(void)
{
    m_logger.LogInfo("Initializing CapitalAllocator...");
    m_isInitialized = true;
    m_logger.LogInfo("CapitalAllocator initialized");
    return true;
}

void CCapitalAllocator::Update(void)
{
}

void CCapitalAllocator::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_isInitialized = false;
}

double CCapitalAllocator::CalculateSize(const AllocationRequest &request, const PortfolioExposure &exposure) const
{
    if(!m_isInitialized)
        return 0.0;

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equity <= 0.0)
        return 0.0;

    switch(m_policy)
    {
        case ALLOC_FIXED_PERCENT:
        {
            double riskCapital = equity * (m_fixedPercent / 100.0);
            double stopDistPoints = MathAbs(request.entryPrice - request.stopLoss) / _Point;
            if(stopDistPoints <= 0.0)
                return 0.0;

            double tickValue = SymbolInfoDouble(request.symbol, SYMBOL_TRADE_TICK_VALUE);
            double tickSize = SymbolInfoDouble(request.symbol, SYMBOL_TRADE_TICK_SIZE);
            if(tickSize <= 0.0)
                return 0.0;

            //--- H7 (integrity): risk per lot must be scaled by the real
            //    tick size relative to point.  The previous literal 1.0
            //    denominator silently divided by the wrong quantity
            //    whenever tickSize != point (e.g. US30/indices), which
            //    distorted the lot size.  Mirrors the PositionSizer
            //    formula: riskPerLot = stopDistPoints * tickValue /
            //    (tickSize / point).
            double riskPerLot = (stopDistPoints * tickValue) / (tickSize / _Point);
            if(riskPerLot <= 0.0)
                return 0.0;

            double lots = riskCapital / riskPerLot;
            double minLot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
            double maxLot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MAX);
            double lotStep = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_STEP);

            lots = MathMax(lots, minLot);
            lots = MathMin(lots, maxLot);
            if(lotStep > 0.0)
                lots = MathRound(lots / lotStep) * lotStep;

            return lots;
        }

        case ALLOC_FIXED_LOT:
        {
            return m_fixedLots;
        }

        case ALLOC_VOLATILITY_SCALED:
        {
            double baseLots = (m_policy == ALLOC_FIXED_LOT) ? m_fixedLots : 0.01;
            double atr = 0.0;
            double atrBuffer[];
            ArraySetAsSeries(atrBuffer, true);
            int atrHandle = iATR(request.symbol, PERIOD_CURRENT, 14);
            if(atrHandle != INVALID_HANDLE)
            {
                if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
                    atr = atrBuffer[0];
                IndicatorRelease(atrHandle);
            }

            if(atr > 0.0)
            {
                double normAtr = atr / _Point;
                double scale = 50.0 / MathMax(normAtr, 10.0);
                return baseLots * MathMin(scale, 3.0);
            }
            return baseLots;
        }

        case ALLOC_EQUAL_RISK:
        {
            double equitySlice = equity / MathMax(exposure.totalPositions + 1, 1);
            double riskCapital = equitySlice * (m_fixedPercent / 100.0);
            double stopDistPoints = MathAbs(request.entryPrice - request.stopLoss) / _Point;
            if(stopDistPoints <= 0.0)
                return 0.0;

            double tickValue = SymbolInfoDouble(request.symbol, SYMBOL_TRADE_TICK_VALUE);
            double riskPerLot = stopDistPoints * tickValue;
            if(riskPerLot <= 0.0)
                return 0.0;

            double lots = riskCapital / riskPerLot;
            double minLot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
            double lotStep = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_STEP);
            lots = MathMax(lots, minLot);
            if(lotStep > 0.0)
                lots = MathRound(lots / lotStep) * lotStep;

            return lots;
        }

        default:
            return 0.0;
    }
}

string CCapitalAllocator::PolicyName(void) const
{
    switch(m_policy)
    {
        case ALLOC_FIXED_PERCENT:    return "FixedPercent";
        case ALLOC_FIXED_LOT:        return "FixedLot";
        case ALLOC_VOLATILITY_SCALED: return "VolatilityScaled";
        case ALLOC_EQUAL_RISK:       return "EqualRisk";
        default:                     return "Unknown";
    }
}

#endif
