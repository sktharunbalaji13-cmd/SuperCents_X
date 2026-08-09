//+------------------------------------------------------------------+
//|                                         EntrySetupBuilder.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __ENTRY_SETUP_BUILDER_MQH__
#define __ENTRY_SETUP_BUILDER_MQH__

#include "../Core/Logger.mqh"
#include "../Confluence/SignalTypes.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "EntrySetup.mqh"

#define BUILDER_DEFAULT_RR 2.0

class CEntrySetupBuilder
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    CBOSDetector           *m_bosDetector;
    CCHOCHDetector         *m_chochDetector;
    COrderBlockDetector    *m_obDetector;
    CFVGDetector           *m_fvgDetector;
    CProtectedPointManager *m_ppManager;

    double m_riskRewardRatio;

    bool FindBOSById(int id, BOSEvent &out);
    bool FindCHOCHById(int id, CHOCHEvent &out);
    bool FindOBById(int id, OrderBlock &out);
    bool FindFVGById(int id, FairValueGap &out);
    bool FindSLFromProtected(Trend direction, double &stopPrice);

    bool BuildBOS(const BOSEvent &bos, const ConfluenceSignal &signal, EntrySetup &out);
    bool BuildCHOCH(const CHOCHEvent &choch, const ConfluenceSignal &signal, EntrySetup &out);
    bool BuildOB(const OrderBlock &ob, const ConfluenceSignal &signal, EntrySetup &out);
    bool BuildFVG(const FairValueGap &fvg, const ConfluenceSignal &signal, EntrySetup &out);

public:
    CEntrySetupBuilder(void);
    ~CEntrySetupBuilder(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetBOSDetector(CBOSDetector *detector) { m_bosDetector = detector; }
    void SetCHOCHDetector(CCHOCHDetector *detector) { m_chochDetector = detector; }
    void SetOBDetector(COrderBlockDetector *detector) { m_obDetector = detector; }
    void SetFVGDetector(CFVGDetector *detector) { m_fvgDetector = detector; }
    void SetPPManager(CProtectedPointManager *manager) { m_ppManager = manager; }

    bool Build(const ConfluenceSignal &signal, EntrySetup &out);

    void SetRiskRewardRatio(double rr) { m_riskRewardRatio = rr; }
};

CEntrySetupBuilder::CEntrySetupBuilder(void)
    : m_logger(MODULE_ENTRY_SETUP_BUILDER, "EntrySetupBuilder")
    , m_isInitialized(false)
    , m_bosDetector(NULL)
    , m_chochDetector(NULL)
    , m_obDetector(NULL)
    , m_fvgDetector(NULL)
    , m_ppManager(NULL)
    , m_riskRewardRatio(BUILDER_DEFAULT_RR) {}

CEntrySetupBuilder::~CEntrySetupBuilder(void) {}

bool CEntrySetupBuilder::Init(void)
{
    m_logger.LogInfo("Initializing EntrySetupBuilder...");
    m_isInitialized = true;
    m_logger.LogInfo("EntrySetupBuilder initialized");
    return true;
}

void CEntrySetupBuilder::Shutdown(void)
{
    m_isInitialized = false;
}

bool CEntrySetupBuilder::Build(const ConfluenceSignal &signal, EntrySetup &out)
{
    if(!m_isInitialized)
        return false;

    if(signal.direction == CONFLUENCE_NONE)
        return false;

    out.valid              = false;
    out.signalTime         = signal.time;
    out.confluenceScore    = signal.score.total;
    out.riskRewardRatio    = m_riskRewardRatio;
    out.bosId              = signal.bosId;
    out.chochId            = signal.chochId;
    out.obId               = signal.orderBlockId;
    out.fvgId              = signal.fvgId;
    out.protectedPointId   = signal.protectedPointId;

    if(signal.direction == CONFLUENCE_BULLISH)
        out.direction = TREND_BULLISH;
    else
        out.direction = TREND_BEARISH;

    if(signal.hasCHOCH)
    {
        CHOCHEvent choch;
        if(signal.chochId > 0 && FindCHOCHById(signal.chochId, choch))
        {
            if(BuildCHOCH(choch, signal, out))
                return true;
        }
    }

    if(signal.hasBOS)
    {
        BOSEvent bos;
        if(signal.bosId > 0 && FindBOSById(signal.bosId, bos))
        {
            if(BuildBOS(bos, signal, out))
                return true;
        }
    }

    if(signal.hasOrderBlock)
    {
        OrderBlock ob;
        if(signal.orderBlockId > 0 && FindOBById(signal.orderBlockId, ob))
        {
            if(BuildOB(ob, signal, out))
                return true;
        }
    }

    if(signal.hasFVG)
    {
        FairValueGap fvg;
        if(signal.fvgId > 0 && FindFVGById(signal.fvgId, fvg))
        {
            if(BuildFVG(fvg, signal, out))
                return true;
        }
    }

    return false;
}

bool CEntrySetupBuilder::BuildBOS(const BOSEvent &bos, const ConfluenceSignal &signal, EntrySetup &out)
{
    out.type      = SETUP_BOS_CONTINUATION;
    out.entryPrice = bos.pivotPrice;

    if(!FindSLFromProtected(out.direction, out.stopLoss))
        return false;

    if(out.stopLoss == out.entryPrice)
        return false;

    double risk = MathAbs(out.entryPrice - out.stopLoss);
    out.takeProfit = (out.direction == TREND_BULLISH)
        ? out.entryPrice + risk * m_riskRewardRatio
        : out.entryPrice - risk * m_riskRewardRatio;

    out.valid = true;

    m_logger.LogInfo(StringFormat("BOS setup #%d: %s entry=%.5f SL=%.5f TP=%.5f RR=%.1f score=%d",
        bos.id, (out.direction == TREND_BULLISH ? "BUY" : "SELL"),
        out.entryPrice, out.stopLoss, out.takeProfit, m_riskRewardRatio, signal.score.total));
    return true;
}

bool CEntrySetupBuilder::BuildCHOCH(const CHOCHEvent &choch, const ConfluenceSignal &signal, EntrySetup &out)
{
    out.type      = SETUP_CHOCH_REVERSAL;
    out.entryPrice = choch.breakPrice;

    if(!FindSLFromProtected(out.direction, out.stopLoss))
        return false;

    if(out.stopLoss == out.entryPrice)
        return false;

    double risk = MathAbs(out.entryPrice - out.stopLoss);
    out.takeProfit = (out.direction == TREND_BULLISH)
        ? out.entryPrice + risk * m_riskRewardRatio
        : out.entryPrice - risk * m_riskRewardRatio;

    out.valid = true;

    m_logger.LogInfo(StringFormat("CHOCH setup #%d: %s entry=%.5f SL=%.5f TP=%.5f RR=%.1f score=%d",
        choch.id, (out.direction == TREND_BULLISH ? "BUY" : "SELL"),
        out.entryPrice, out.stopLoss, out.takeProfit, m_riskRewardRatio, signal.score.total));
    return true;
}

bool CEntrySetupBuilder::BuildOB(const OrderBlock &ob, const ConfluenceSignal &signal, EntrySetup &out)
{
    out.type = SETUP_ORDERBLOCK_RETEST;
    out.entryPrice = ob.bullish ? ob.high : ob.low;
    out.stopLoss   = ob.bullish ? ob.low  : ob.high;

    if(out.stopLoss == out.entryPrice)
        return false;

    double risk = MathAbs(out.entryPrice - out.stopLoss);
    out.takeProfit = (out.direction == TREND_BULLISH)
        ? out.entryPrice + risk * m_riskRewardRatio
        : out.entryPrice - risk * m_riskRewardRatio;

    out.valid = true;

    m_logger.LogInfo(StringFormat("OB setup #%d: %s entry=%.5f SL=%.5f TP=%.5f RR=%.1f score=%d",
        ob.id, (out.direction == TREND_BULLISH ? "BUY" : "SELL"),
        out.entryPrice, out.stopLoss, out.takeProfit, m_riskRewardRatio, signal.score.total));
    return true;
}

bool CEntrySetupBuilder::BuildFVG(const FairValueGap &fvg, const ConfluenceSignal &signal, EntrySetup &out)
{
    out.type      = SETUP_FVG_CONTINUATION;
    out.entryPrice = (fvg.upper + fvg.lower) / 2.0;
    out.stopLoss   = fvg.bullish ? fvg.lower : fvg.upper;

    if(out.stopLoss == out.entryPrice)
        return false;

    double risk = MathAbs(out.entryPrice - out.stopLoss);
    out.takeProfit = (out.direction == TREND_BULLISH)
        ? out.entryPrice + risk * m_riskRewardRatio
        : out.entryPrice - risk * m_riskRewardRatio;

    out.valid = true;

    m_logger.LogInfo(StringFormat("FVG setup #%d: %s entry=%.5f SL=%.5f TP=%.5f RR=%.1f score=%d",
        fvg.id, (out.direction == TREND_BULLISH ? "BUY" : "SELL"),
        out.entryPrice, out.stopLoss, out.takeProfit, m_riskRewardRatio, signal.score.total));
    return true;
}

bool CEntrySetupBuilder::FindSLFromProtected(Trend direction, double &stopPrice)
{
    if(m_ppManager == NULL)
        return false;

    ProtectedPoint buffer;
    if(direction == TREND_BULLISH)
    {
        if(m_ppManager.GetActiveLow(buffer))
        {
            stopPrice = buffer.price;
            return true;
        }
    }
    else
    {
        if(m_ppManager.GetActiveHigh(buffer))
        {
            stopPrice = buffer.price;
            return true;
        }
    }

    return false;
}

bool CEntrySetupBuilder::FindBOSById(int id, BOSEvent &out)
{
    if(m_bosDetector == NULL)
        return false;

    int count = m_bosDetector.GetBOSCount();
    for(int i = 0; i < count; i++)
    {
        if(m_bosDetector.GetBOS(i, out) && out.id == id)
            return true;
    }
    return false;
}

bool CEntrySetupBuilder::FindCHOCHById(int id, CHOCHEvent &out)
{
    if(m_chochDetector == NULL)
        return false;

    int count = m_chochDetector.GetCHOCHCount();
    for(int i = 0; i < count; i++)
    {
        if(m_chochDetector.GetCHOCH(i, out) && out.id == id)
            return true;
    }
    return false;
}

bool CEntrySetupBuilder::FindOBById(int id, OrderBlock &out)
{
    if(m_obDetector == NULL)
        return false;

    int count = m_obDetector.GetOrderBlockCount();
    for(int i = 0; i < count; i++)
    {
        if(m_obDetector.GetOrderBlock(i, out) && out.id == id)
            return true;
    }
    return false;
}

bool CEntrySetupBuilder::FindFVGById(int id, FairValueGap &out)
{
    if(m_fvgDetector == NULL)
        return false;

    int count = m_fvgDetector.GetFVGCount();
    for(int i = 0; i < count; i++)
    {
        if(m_fvgDetector.GetFVG(i, out) && out.id == id)
            return true;
    }
    return false;
}

#endif
