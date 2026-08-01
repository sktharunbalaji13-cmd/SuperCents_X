#ifndef __CONFLUENCE_SCORE_CALCULATOR_MQH__
#define __CONFLUENCE_SCORE_CALCULATOR_MQH__

#include "ConfluenceWeights.mqh"

class CConfluenceScoreCalculator
{
private:
    ConfluenceWeights m_weights;

public:
    void SetWeights(const ConfluenceWeights &weights)
    {
        m_weights = weights;
    }

    ConfluenceWeights GetWeights(void) const
    {
        return m_weights;
    }

    double Calculate(ConfluenceComponentResult &components[], int count,
                     ConfluenceResult &result)
    {
        if(count <= 0 || count > MAX_CONFLUENCE_COMPONENTS)
            return 0.0;

        double total = 0.0;
        int validCount = 0;

        result.componentCount = count;
        string explanation = "";

        for(int i = 0; i < count; i++)
        {
            ENUM_CONFLUENCE_COMPONENT type = components[i].type;
            double weight = m_weights.GetWeight(type);
            double score = (type >= 0 && type < COMPONENT_COUNT) ? fmax(0.0, fmin(100.0, components[i].score)) : 0.0;
            double contribution = score * (weight / 100.0);

            result.components[i] = components[i];
            result.components[i].weight = weight;
            result.components[i].contribution = contribution;
            result.components[i].score = score;

            if(score > 0.0)
                validCount++;

            total += contribution;

            if(explanation != "")
                explanation += "; ";
            explanation += components[i].explanation;
        }

        result.totalConfidence = fmin(100.0, fmax(0.0, total));
        result.summaryExplanation = explanation;
        result.valid = (validCount > 0 && total > 0.0);

        return result.totalConfidence;
    }
};

#endif
