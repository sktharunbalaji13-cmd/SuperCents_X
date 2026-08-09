#ifndef __KNOWLEDGE_STRATEGY_LINEAGE_MQH__
#define __KNOWLEDGE_STRATEGY_LINEAGE_MQH__

#include "../Core/Logger.mqh"
#include "../Laboratory/LaboratoryTypes.mqh"
#include "KnowledgeEvidence.mqh"

#define MAX_LINEAGE_NODES 256
#define MAX_LINEAGE_EDGES 512

class CStrategyLineage
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    StrategyVersionNode m_nodes[MAX_LINEAGE_NODES];
    int                 m_nodeCount;
    LineageEdge         m_edges[MAX_LINEAGE_EDGES];
    int                 m_edgeCount;

    int FindVersion(const string strategyId, const string version) const;
    int FindVersionByTag(const string versionTag) const;
    double ComputeDelta(double parentScore, double childScore) const;
    ENUM_LINEAGE_RELATIONSHIP ClassifyChange(const string changeDescription) const;

public:
    CStrategyLineage(void);
    ~CStrategyLineage(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool RegisterVersion(const string strategyId, const string version,
                          const string versionTag, const string description,
                          double performanceScore);
    bool RegisterVersion(const StrategyVersionNode &node);

    bool AddLineageEdge(const string parentStrategyId, const string parentVersion,
                         const string childStrategyId, const string childVersion,
                         const string changeDescription);
    bool AddLineageEdge(const LineageEdge &edge);

    bool AttachPerformanceDelta(const string childStrategyId, const string childVersion,
                                 double parentPerformance, double childPerformance);

    int  GetAncestors(const string strategyId, const string version,
                       StrategyVersionNode &out[], int maxCount) const;
    int  GetDescendants(const string strategyId, const string version,
                         StrategyVersionNode &out[], int maxCount) const;
    int  GetLineage(const string strategyId, StrategyVersionNode &out[], int maxCount) const;

    int  GetNodeCount(void) const { return m_nodeCount; }
    int  GetEdgeCount(void) const { return m_edgeCount; }
    bool GetNode(int index, StrategyVersionNode &out) const;

    string ComposeLineageReport(const string strategyId, const string version) const;
    string ComposeVersionTree(const string strategyId) const;

    void Clear(void);
};

CStrategyLineage::CStrategyLineage(void)
    : m_logger(MODULE_LABORATORY, "StrategyLineage")
    , m_isInitialized(false)
    , m_nodeCount(0)
    , m_edgeCount(0)
{
}

CStrategyLineage::~CStrategyLineage(void)
{
    Shutdown();
}

bool CStrategyLineage::Init(void)
{
    m_logger.LogInfo("Initializing StrategyLineage...");
    m_nodeCount = 0;
    m_edgeCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("StrategyLineage initialized");
    return true;
}

void CStrategyLineage::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

int CStrategyLineage::FindVersion(const string strategyId, const string version) const
{
    for(int i = 0; i < m_nodeCount; i++)
        if(m_nodes[i].strategyId == strategyId && m_nodes[i].version == version)
            return i;
    return -1;
}

int CStrategyLineage::FindVersionByTag(const string versionTag) const
{
    for(int i = 0; i < m_nodeCount; i++)
        if(m_nodes[i].versionTag == versionTag)
            return i;
    return -1;
}

double CStrategyLineage::ComputeDelta(double parentScore, double childScore) const
{
    if(parentScore == 0.0) return 0.0;
    return (childScore - parentScore) / MathAbs(parentScore) * 100.0;
}

ENUM_LINEAGE_RELATIONSHIP CStrategyLineage::ClassifyChange(const string changeDescription) const
{
    string lower = changeDescription;
    StringToLower(lower);

    if(StringFind(lower, "parameter") >= 0 || StringFind(lower, "param") >= 0)
        return LINEAGE_PARAMETER_CHANGE;
    if(StringFind(lower, "fork") >= 0 || StringFind(lower, "branch") >= 0)
        return LINEAGE_STRATEGY_FORK;
    if(StringFind(lower, "confidence") >= 0 || StringFind(lower, "entry") >= 0)
        return LINEAGE_CONFIDENCE_ADDED;
    if(StringFind(lower, "confluence") >= 0)
        return LINEAGE_CONFLUENCE_ADDED;
    if(StringFind(lower, "fvg") >= 0)
        return LINEAGE_FVG_ADDED;
    if(StringFind(lower, "ob") >= 0 || StringFind(lower, "order block") >= 0)
        return LINEAGE_OB_ADDED;
    if(StringFind(lower, "research") >= 0)
        return LINEAGE_RESEARCH_ADDED;
    if(StringFind(lower, "production") >= 0 || StringFind(lower, "operational") >= 0)
        return LINEAGE_PRODUCTION_ADDED;

    return LINEAGE_VERSION_BUMP;
}

bool CStrategyLineage::RegisterVersion(const string strategyId, const string version,
                                         const string versionTag, const string description,
                                         double performanceScore)
{
    if(!m_isInitialized || m_nodeCount >= MAX_LINEAGE_NODES)
        return false;

    if(FindVersion(strategyId, version) >= 0)
        return true;

    StrategyVersionNode node;
    node.strategyId = strategyId;
    node.version = version;
    node.versionTag = versionTag;
    node.description = description;
    node.performanceScore = performanceScore;
    node.timestamp = TimeCurrent();

    m_nodes[m_nodeCount] = node;
    m_nodeCount++;

    m_logger.LogInfo(StringFormat("Lineage: registered %s@%s (%s) score=%.4f",
                                  strategyId, version, versionTag, performanceScore));
    return true;
}

bool CStrategyLineage::RegisterVersion(const StrategyVersionNode &node)
{
    return RegisterVersion(node.strategyId, node.version,
                            node.versionTag, node.description,
                            node.performanceScore);
}

bool CStrategyLineage::AddLineageEdge(const string parentStrategyId, const string parentVersion,
                                       const string childStrategyId, const string childVersion,
                                       const string changeDescription)
{
    if(!m_isInitialized || m_edgeCount >= MAX_LINEAGE_EDGES)
        return false;

    int parentIdx = FindVersion(parentStrategyId, parentVersion);
    int childIdx = FindVersion(childStrategyId, childVersion);

    if(parentIdx < 0 || childIdx < 0)
        return false;

    LineageEdge edge;
    edge.parentStrategyId = parentStrategyId;
    edge.parentVersion = parentVersion;
    edge.childStrategyId = childStrategyId;
    edge.childVersion = childVersion;
    edge.relationship = ClassifyChange(changeDescription);
    edge.performanceDelta = ComputeDelta(m_nodes[parentIdx].performanceScore,
                                          m_nodes[childIdx].performanceScore);
    edge.changeDescription = changeDescription;

    KnowledgeEvidence ev;
    ev.source = "StrategyLineage";
    ev.dimension = "performanceDelta";
    ev.value = edge.performanceDelta;
    ev.rationale = changeDescription;
    ev.artifactRef = StringFormat("%s@%s->%s@%s", parentStrategyId, parentVersion,
                                   childStrategyId, childVersion);
    ev.versionContext = childVersion;
    edge.evidence[edge.evidenceCount] = ev;
    edge.evidenceCount++;

    m_edges[m_edgeCount] = edge;
    m_edgeCount++;

    m_logger.LogInfo(StringFormat("Lineage edge: %s@%s -> %s@%s delta=%.2f%% [%s]",
                                  parentStrategyId, parentVersion,
                                  childStrategyId, childVersion,
                                  edge.performanceDelta, changeDescription));
    return true;
}

bool CStrategyLineage::AddLineageEdge(const LineageEdge &edge)
{
    return AddLineageEdge(edge.parentStrategyId, edge.parentVersion,
                           edge.childStrategyId, edge.childVersion,
                           edge.changeDescription);
}

bool CStrategyLineage::AttachPerformanceDelta(const string childStrategyId,
                                               const string childVersion,
                                               double parentPerformance,
                                               double childPerformance)
{
    int childIdx = FindVersion(childStrategyId, childVersion);
    if(childIdx < 0) return false;

    m_nodes[childIdx].performanceScore = childPerformance;

    for(int i = 0; i < m_edgeCount; i++)
    {
        if(m_edges[i].childStrategyId == childStrategyId &&
           m_edges[i].childVersion == childVersion)
        {
            m_edges[i].performanceDelta = ComputeDelta(parentPerformance, childPerformance);
            return true;
        }
    }
    return false;
}

int CStrategyLineage::GetAncestors(const string strategyId, const string version,
                                    StrategyVersionNode &out[], int maxCount) const
{
    int count = 0;
    string currentId = strategyId;
    string currentVer = version;

    for(int i = 0; i < MAX_LINEAGE_EDGES && count < maxCount; i++)
    {
        bool found = false;
        for(int j = 0; j < m_edgeCount; j++)
        {
            if(m_edges[j].childStrategyId == currentId &&
               m_edges[j].childVersion == currentVer)
            {
                int parentIdx = FindVersion(m_edges[j].parentStrategyId,
                                             m_edges[j].parentVersion);
                if(parentIdx >= 0)
                {
                    out[count] = m_nodes[parentIdx];
                    count++;
                    currentId = m_edges[j].parentStrategyId;
                    currentVer = m_edges[j].parentVersion;
                    found = true;
                    break;
                }
            }
        }
        if(!found) break;
    }

    return count;
}

int CStrategyLineage::GetDescendants(const string strategyId, const string version,
                                      StrategyVersionNode &out[], int maxCount) const
{
    int count = 0;
    string currentId = strategyId;
    string currentVer = version;

    for(int i = 0; i < MAX_LINEAGE_EDGES && count < maxCount; i++)
    {
        bool found = false;
        for(int j = 0; j < m_edgeCount; j++)
        {
            if(m_edges[j].parentStrategyId == currentId &&
               m_edges[j].parentVersion == currentVer)
            {
                int childIdx = FindVersion(m_edges[j].childStrategyId,
                                            m_edges[j].childVersion);
                if(childIdx >= 0)
                {
                    out[count] = m_nodes[childIdx];
                    count++;
                    currentId = m_edges[j].childStrategyId;
                    currentVer = m_edges[j].childVersion;
                    found = true;
                    break;
                }
            }
        }
        if(!found) break;
    }

    return count;
}

int CStrategyLineage::GetLineage(const string strategyId,
                                  StrategyVersionNode &out[], int maxCount) const
{
    int count = 0;

    for(int i = 0; i < m_nodeCount && count < maxCount; i++)
    {
        if(m_nodes[i].strategyId == strategyId)
        {
            out[count] = m_nodes[i];
            count++;
        }
    }

    return count;
}

bool CStrategyLineage::GetNode(int index, StrategyVersionNode &out) const
{
    if(index < 0 || index >= m_nodeCount) return false;
    out = m_nodes[index];
    return true;
}

string CStrategyLineage::ComposeLineageReport(const string strategyId,
                                               const string version) const
{
    string out = "";
    out += "========================================\n";
    out += "STRATEGY LINEAGE\n";
    out += "========================================\n";

    StrategyVersionNode ancestors[64];
    int ancCount = GetAncestors(strategyId, version, ancestors, 64);

    if(ancCount > 0)
    {
        out += "  Ancestors:\n";
        for(int i = ancCount - 1; i >= 0; i--)
        {
            out += StringFormat("    [%s] %s@%s score=%.4f\n",
                                ancestors[i].versionTag,
                                ancestors[i].strategyId,
                                ancestors[i].version,
                                ancestors[i].performanceScore);
        }
    }

    int nodeIdx = FindVersion(strategyId, version);
    if(nodeIdx >= 0)
    {
        out += StringFormat("  [CURRENT] %s@%s (%s) score=%.4f\n",
                            m_nodes[nodeIdx].versionTag,
                            m_nodes[nodeIdx].strategyId,
                            m_nodes[nodeIdx].version,
                            m_nodes[nodeIdx].performanceScore);
    }

    StrategyVersionNode descendants[64];
    int descCount = GetDescendants(strategyId, version, descendants, 64);

    if(descCount > 0)
    {
        out += "  Descendants:\n";
        for(int i = 0; i < descCount; i++)
        {
            out += StringFormat("    [%s] %s@%s score=%.4f\n",
                                descendants[i].versionTag,
                                descendants[i].strategyId,
                                descendants[i].version,
                                descendants[i].performanceScore);
        }
    }

    out += "----------------------------------------\n";
    out += "  Edges:\n";
    for(int i = 0; i < m_edgeCount; i++)
    {
        if(m_edges[i].childStrategyId == strategyId ||
           m_edges[i].parentStrategyId == strategyId)
        {
            out += StringFormat("    %s@%s -> %s@%s [%s] delta=%.2f%%\n",
                                m_edges[i].parentStrategyId,
                                m_edges[i].parentVersion,
                                m_edges[i].childStrategyId,
                                m_edges[i].childVersion,
                                m_edges[i].changeDescription,
                                m_edges[i].performanceDelta);
        }
    }

    out += "========================================\n";
    return out;
}

string CStrategyLineage::ComposeVersionTree(const string strategyId) const
{
    string out = "";
    out += StringFormat("Version tree for '%s':\n", strategyId);
    out += "----------------------------------------\n";

    for(int i = 0; i < m_edgeCount; i++)
    {
        if(m_edges[i].childStrategyId == strategyId ||
           m_edges[i].parentStrategyId == strategyId)
        {
            out += StringFormat("  %s@%s\n", m_edges[i].parentStrategyId,
                                m_edges[i].parentVersion);
            out += StringFormat("    |-- %s [%.2f%%]\n",
                                m_edges[i].changeDescription,
                                m_edges[i].performanceDelta);
            out += StringFormat("    v\n");
            out += StringFormat("  %s@%s\n", m_edges[i].childStrategyId,
                                m_edges[i].childVersion);
            out += "\n";
        }
    }

    out += "----------------------------------------\n";
    return out;
}

void CStrategyLineage::Clear(void)
{
    m_nodeCount = 0;
    m_edgeCount = 0;
}

#endif
