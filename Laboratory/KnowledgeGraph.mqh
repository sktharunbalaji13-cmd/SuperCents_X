#ifndef __LABORATORY_KNOWLEDGE_GRAPH_MQH__
#define __LABORATORY_KNOWLEDGE_GRAPH_MQH__

#include "../Core/Logger.mqh"
#include "LaboratoryTypes.mqh"

#define MAX_GRAPH_NODES 256
#define MAX_GRAPH_EDGES 1024

class CKnowledgeGraph
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    string        m_nodes[MAX_GRAPH_NODES];
    int           m_nodeCount;
    KnowledgeEdge m_edges[MAX_GRAPH_EDGES];
    int           m_edgeCount;

    int FindNode(const string nodeId) const;

public:
    CKnowledgeGraph(void);
    ~CKnowledgeGraph(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool AddNode(const string nodeId);
    bool AddEdge(const string fromId, const string toId,
                 const string relationship, double weight);

    bool LinkExperimentToStrategy(const string experimentId, const string strategyId);
    bool LinkStrategyToBenchmark(const string strategyId, const string benchmarkId,
                                  double alpha);
    bool LinkComparison(const string leftId, const string rightId, double score);

    bool GetEdgesFrom(const string nodeId, KnowledgeEdge &out[], int &count) const;
    bool GetEdgesTo(const string nodeId, KnowledgeEdge &out[], int &count) const;
    bool HasNode(const string nodeId) const;
    int  GetNodeCount(void) const { return m_nodeCount; }
    int  GetEdgeCount(void) const { return m_edgeCount; }
    bool GetNode(int index, string &out) const;

    void Clear(void);
};

CKnowledgeGraph::CKnowledgeGraph(void)
    : m_logger(MODULE_LABORATORY, "KnowledgeGraph")
    , m_isInitialized(false)
    , m_nodeCount(0)
    , m_edgeCount(0)
{
}

CKnowledgeGraph::~CKnowledgeGraph(void)
{
    Shutdown();
}

bool CKnowledgeGraph::Init(void)
{
    m_logger.LogInfo("Initializing KnowledgeGraph...");
    m_nodeCount = 0;
    m_edgeCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("KnowledgeGraph initialized");
    return true;
}

void CKnowledgeGraph::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

int CKnowledgeGraph::FindNode(const string nodeId) const
{
    for(int i = 0; i < m_nodeCount; i++)
        if(m_nodes[i] == nodeId) return i;
    return -1;
}

bool CKnowledgeGraph::AddNode(const string nodeId)
{
    if(!m_isInitialized || m_nodeCount >= MAX_GRAPH_NODES)
        return false;
    if(FindNode(nodeId) >= 0)
        return true;

    m_nodes[m_nodeCount] = nodeId;
    m_nodeCount++;
    return true;
}

bool CKnowledgeGraph::AddEdge(const string fromId, const string toId,
                               const string relationship, double weight)
{
    if(!m_isInitialized || m_edgeCount >= MAX_GRAPH_EDGES)
        return false;

    AddNode(fromId);
    AddNode(toId);

    KnowledgeEdge edge;
    edge.fromId = fromId;
    edge.toId = toId;
    edge.relationship = relationship;
    edge.weight = weight;

    m_edges[m_edgeCount] = edge;
    m_edgeCount++;
    return true;
}

bool CKnowledgeGraph::LinkExperimentToStrategy(const string experimentId,
                                                 const string strategyId)
{
    return AddEdge(experimentId, strategyId, "EXPERIMENT_OF", 1.0);
}

bool CKnowledgeGraph::LinkStrategyToBenchmark(const string strategyId,
                                               const string benchmarkId,
                                               double alpha)
{
    return AddEdge(strategyId, benchmarkId, "COMPARED_TO", alpha);
}

bool CKnowledgeGraph::LinkComparison(const string leftId, const string rightId,
                                      double score)
{
    return AddEdge(leftId, rightId, "COMPARED_WITH", score);
}

bool CKnowledgeGraph::GetEdgesFrom(const string nodeId,
                                    KnowledgeEdge &out[], int &count) const
{
    count = 0;
    for(int i = 0; i < m_edgeCount; i++)
    {
        if(m_edges[i].fromId == nodeId)
        {
            out[count] = m_edges[i];
            count++;
        }
    }
    return count > 0;
}

bool CKnowledgeGraph::GetEdgesTo(const string nodeId,
                                  KnowledgeEdge &out[], int &count) const
{
    count = 0;
    for(int i = 0; i < m_edgeCount; i++)
    {
        if(m_edges[i].toId == nodeId)
        {
            out[count] = m_edges[i];
            count++;
        }
    }
    return count > 0;
}

bool CKnowledgeGraph::HasNode(const string nodeId) const
{
    return FindNode(nodeId) >= 0;
}

bool CKnowledgeGraph::GetNode(int index, string &out) const
{
    if(index < 0 || index >= m_nodeCount) return false;
    out = m_nodes[index];
    return true;
}

void CKnowledgeGraph::Clear(void)
{
    m_nodeCount = 0;
    m_edgeCount = 0;
}

#endif
