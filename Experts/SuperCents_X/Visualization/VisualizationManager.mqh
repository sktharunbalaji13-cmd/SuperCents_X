//+------------------------------------------------------------------+
//|                                      VisualizationManager.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __VISUALIZATION_MANAGER_MQH__
#define __VISUALIZATION_MANAGER_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "RenderConfig.mqh"
#include "VisualStateEngine.mqh"
#include "../Structure/SwingDetector.mqh"
#include "../Structure/StructuralPivotEngine.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "SwingRenderer.mqh"
#include "PivotRenderer.mqh"
#include "BOSRenderer.mqh"
#include "CHOCHRenderer.mqh"
#include "ProtectedRenderer.mqh"
#include "OrderBlockRenderer.mqh"
#include "FVGRenderer.mqh"
#include "LiquidityRenderer.mqh"
#include "VisualDiagnostic.mqh"

class CVisualizationManager
{
private:
    CLogger m_logger;
    bool m_isInitialized;

    CSwingDetector              *m_swingDetector;
    CStructuralPivotEngine      *m_pivotEngine;
    CBOSDetector                *m_bosDetector;
    CCHOCHDetector              *m_chochDetector;
    CProtectedPointManager      *m_protectedPointManager;
    COrderBlockDetector         *m_orderBlockDetector;
    CFVGDetector                *m_fvgDetector;
    CLiquidityDetector          *m_liquidityDetector;

    CVisualStateEngine  m_vse;

    CSwingRenderer      m_swing;
    CPivotRenderer      m_pivot;
    CBOSRenderer        m_bos;
    CCHOCHRenderer      m_choch;
    CProtectedRenderer  m_protected;
    COrderBlockRenderer m_ob;
    CFVGRenderer        m_fvg;
    CLiquidityRenderer  m_liquidity;
    CVisualDiagnostic   m_diag;

public:
    CVisualizationManager(void);
    ~CVisualizationManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetSwingDetector(CSwingDetector *detector);
    void SetPivotEngine(CStructuralPivotEngine *engine);
    void SetBOSDetector(CBOSDetector *detector);
    void SetCHOCHDetector(CCHOCHDetector *detector);
    void SetProtectedPointManager(CProtectedPointManager *manager);
    void SetOrderBlockDetector(COrderBlockDetector *detector);
    void SetFVGDetector(CFVGDetector *detector);
    void SetLiquidityDetector(CLiquidityDetector *detector);
};

CVisualizationManager::CVisualizationManager(void)
    : m_logger(MODULE_VISUALIZATION_MANAGER, "VizManager"), m_isInitialized(false)
    , m_swingDetector(NULL), m_pivotEngine(NULL), m_bosDetector(NULL)
    , m_chochDetector(NULL), m_protectedPointManager(NULL)
    , m_orderBlockDetector(NULL), m_fvgDetector(NULL), m_liquidityDetector(NULL) {}

CVisualizationManager::~CVisualizationManager(void)
{
    Shutdown();
}

bool CVisualizationManager::Init(void)
{
    m_logger.LogInfo("Initializing VisualizationManager...");

    m_vse.Init();
    m_diag.SetVSE(&m_vse);

    // Pass VSE to all renderers
    m_swing.SetVSE(&m_vse);
    m_pivot.SetVSE(&m_vse);
    m_bos.SetVSE(&m_vse);
    m_choch.SetVSE(&m_vse);
    m_protected.SetVSE(&m_vse);
    m_ob.SetVSE(&m_vse);
    m_fvg.SetVSE(&m_vse);
    m_liquidity.SetVSE(&m_vse);

    if(!m_swing.Init())    { m_logger.LogError("SwingRenderer init failed");    return false; }
    if(!m_pivot.Init())    { m_logger.LogError("PivotRenderer init failed");    return false; }
    if(!m_bos.Init())      { m_logger.LogError("BOSRenderer init failed");      return false; }
    if(!m_choch.Init())    { m_logger.LogError("CHOCHRenderer init failed");    return false; }
    if(!m_protected.Init()){ m_logger.LogError("ProtectedRenderer init failed"); return false; }
    if(!m_ob.Init())       { m_logger.LogError("OrderBlockRenderer init failed");return false; }
    if(!m_fvg.Init())      { m_logger.LogError("FVGRenderer init failed");      return false; }
    if(!m_liquidity.Init()){ m_logger.LogError("LiquidityRenderer init failed"); return false; }

    m_isInitialized = true;
    m_logger.LogInfo("VisualizationManager initialized");
    return true;
}

void CVisualizationManager::Update(void)
{
    ulong s, e;
    string perf = "VIZ";

    // Layer order per spec §11: FVG → OB → PP → BOS → CHOCH → Liquidity → Swings → Pivots
    // This ensures rectangles (FVG/OB) are behind lines, arrows on top, labels topmost

    s = GetMicrosecondCount();
    if(ShowFVG)             m_fvg.Update();           else m_fvg.Clear();
    e = GetMicrosecondCount();
    perf += StringFormat(" FVG:%llu", e - s);

    s = GetMicrosecondCount();
    if(ShowOrderBlocks)     m_ob.Update();            else m_ob.Clear();
    e = GetMicrosecondCount();
    perf += StringFormat(" OB:%llu", e - s);

    s = GetMicrosecondCount();
    if(ShowProtectedPoints) m_protected.Update();     else m_protected.Clear();
    e = GetMicrosecondCount();
    perf += StringFormat(" PP:%llu", e - s);

    s = GetMicrosecondCount();
    if(ShowBOS)             m_bos.Update();           else m_bos.Clear();
    e = GetMicrosecondCount();
    perf += StringFormat(" BOS:%llu", e - s);

    s = GetMicrosecondCount();
    if(ShowCHOCH)           m_choch.Update();         else m_choch.Clear();
    e = GetMicrosecondCount();
    perf += StringFormat(" CHOCH:%llu", e - s);

    s = GetMicrosecondCount();
    if(ShowLiquidity)       m_liquidity.Update();     else m_liquidity.Clear();
    e = GetMicrosecondCount();
    perf += StringFormat(" LIQ:%llu", e - s);

    s = GetMicrosecondCount();
    if(ShowSwings)          m_swing.Update();         else m_swing.Clear();
    e = GetMicrosecondCount();
    perf += StringFormat(" Swing:%llu", e - s);

    s = GetMicrosecondCount();
    if(ShowPivots)          m_pivot.Update();         else m_pivot.Clear();
    e = GetMicrosecondCount();
    perf += StringFormat(" Pivot:%llu", e - s);

    m_diag.Check();

    ChartRedraw(0);

    Print(perf);
}

void CVisualizationManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down VisualizationManager...");
    m_isInitialized = false;

    m_fvg.Shutdown();
    m_ob.Shutdown();
    m_protected.Shutdown();
    m_choch.Shutdown();
    m_liquidity.Shutdown();
    m_bos.Shutdown();
    m_pivot.Shutdown();
    m_swing.Shutdown();

    m_vse.Shutdown();

    m_logger.LogInfo("VisualizationManager shutdown complete");
}

void CVisualizationManager::Clear(void)
{
    m_swing.Clear();
    m_pivot.Clear();
    m_bos.Clear();
    m_choch.Clear();
    m_protected.Clear();
    m_ob.Clear();
    m_fvg.Clear();
    m_liquidity.Clear();
}

void CVisualizationManager::SetSwingDetector(CSwingDetector *detector)
{
    m_swingDetector = detector;
    m_swing.SetDetector(detector);
}

void CVisualizationManager::SetPivotEngine(CStructuralPivotEngine *engine)
{
    m_pivotEngine = engine;
    m_pivot.SetDetector(engine);
    m_bos.SetPivotEngine(engine);
}

void CVisualizationManager::SetBOSDetector(CBOSDetector *detector)
{
    m_bosDetector = detector;
    m_bos.SetDetector(detector);
}

void CVisualizationManager::SetCHOCHDetector(CCHOCHDetector *detector)
{
    m_chochDetector = detector;
    m_choch.SetDetector(detector);
}

void CVisualizationManager::SetProtectedPointManager(CProtectedPointManager *manager)
{
    m_protectedPointManager = manager;
    m_protected.SetDetector(manager);
    m_choch.SetProtectedPointManager(manager);
}

void CVisualizationManager::SetOrderBlockDetector(COrderBlockDetector *detector)
{
    m_orderBlockDetector = detector;
    m_ob.SetDetector(detector);
}

void CVisualizationManager::SetFVGDetector(CFVGDetector *detector)
{
    m_fvgDetector = detector;
    m_fvg.SetDetector(detector);
}

void CVisualizationManager::SetLiquidityDetector(CLiquidityDetector *detector)
{
    m_liquidityDetector = detector;
    m_liquidity.SetDetector(detector);
}

#endif
