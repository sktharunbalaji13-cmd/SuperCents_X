#ifndef __REPORT_TYPES_MQH__
#define __REPORT_TYPES_MQH__

#include "WalkForwardTypes.mqh"
#include "MonteCarloTypes.mqh"
#include "RegressionTypes.mqh"

// @frozen v2.7 -- Public API contract. Append fields only.
struct ValidationReport
{
    string                   title;
    datetime                 generatedAt;
    string                   eaVersion;
    string                   gitCommit;

    ValidationResult         validation;
    bool                     hasWalkForward;
    WalkForwardSummary       walkForward;
    bool                     hasMonteCarlo;
    MonteCarloSummary        monteCarlo;
    bool                     hasRegression;
    RegressionSummary        regression;

    string                   formattedText;

    ValidationReport(void)
        : title("")
        , generatedAt(0)
        , eaVersion("")
        , gitCommit("")
        , hasWalkForward(false)
        , hasMonteCarlo(false)
        , hasRegression(false)
        , formattedText("")
    {}
};

#endif
