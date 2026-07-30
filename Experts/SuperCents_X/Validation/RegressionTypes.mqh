#ifndef __REGRESSION_TYPES_MQH__
#define __REGRESSION_TYPES_MQH__

#include "ValidationTypes.mqh"

#define REGRESSION_EPSILON_PERCENT 0.01

// @frozen v2.7 -- Public API. Append values only.
enum ENUM_REGRESSION_STATUS
{
    REGRESSION_PASS,
    REGRESSION_WARN,
    REGRESSION_FAIL,
    REGRESSION_INSUFFICIENT_DATA
};

// @frozen v2.7 -- Public API. Append values only; no reordering.
enum ENUM_REGRESSION_DIMENSION
{
    REG_DIM_PROFIT_FACTOR,
    REG_DIM_SHARPE_RATIO,
    REG_DIM_SORTINO_RATIO,
    REG_DIM_CALMAR_RATIO,
    REG_DIM_NET_PROFIT,
    REG_DIM_MAX_DRAWDOWN,
    REG_DIM_WIN_RATE,
    REG_DIM_EXPECTANCY,
    REG_DIM_TOTAL_TRADES,
    REG_DIM_AVG_RR,
    REG_DIM_RECOVERY_FACTOR
};

// @frozen v2.7 -- Public API. Append values only.
enum ENUM_CHANGE_DIRECTION
{
    CHANGE_IMPROVED,
    CHANGE_DEGRADED,
    CHANGE_UNCHANGED
};

struct RegressionThreshold
{
    ENUM_REGRESSION_DIMENSION  dimension;
    double                     warnPercent;
    double                     failPercent;
    bool                       higherIsBetter;

    RegressionThreshold(void)
        : dimension(REG_DIM_PROFIT_FACTOR)
        , warnPercent(10.0)
        , failPercent(25.0)
        , higherIsBetter(true)
    {}
};

struct RegressionConfig
{
    int                      configVersion;
    RegressionThreshold      thresholds[];
    int                      thresholdCount;

    RegressionConfig(void)
        : configVersion(1)
        , thresholdCount(0)
    {}
};

struct MetricPair
{
    ENUM_REGRESSION_DIMENSION dimension;
    double                    baseline;
    double                    current;
    bool                      higherIsBetter;

    MetricPair(void)
        : dimension(REG_DIM_PROFIT_FACTOR)
        , baseline(0.0)
        , current(0.0)
        , higherIsBetter(true)
    {}
};

struct RegressionFinding
{
    ENUM_REGRESSION_DIMENSION  dimension;
    ENUM_REGRESSION_STATUS     status;
    ENUM_CHANGE_DIRECTION      direction;
    string                     dimensionLabel;
    double                     baselineValue;
    double                     currentValue;
    double                     delta;
    double                     deltaPercent;
    double                     warnThreshold;
    double                     failThreshold;
    bool                       pctChangeDefined;
    string                     message;

    RegressionFinding(void)
        : dimension(REG_DIM_PROFIT_FACTOR)
        , status(REGRESSION_INSUFFICIENT_DATA)
        , direction(CHANGE_UNCHANGED)
        , dimensionLabel("")
        , baselineValue(0.0)
        , currentValue(0.0)
        , delta(0.0)
        , deltaPercent(0.0)
        , warnThreshold(0.0)
        , failThreshold(0.0)
        , pctChangeDefined(false)
        , message("")
    {}
};

// @frozen v2.7 -- Public API contract. Append fields only.
struct RegressionSummary
{
    string                   experimentLabel;
    string                   baselineValidationId;
    string                   currentValidationId;
    RegressionConfig         config;
    RegressionFinding        findings[];
    int                      totalChecks;
    int                      passedChecks;
    int                      warnedChecks;
    int                      failedChecks;
    int                      insufficientChecks;
    datetime                 compared;
    bool                     completedSuccessfully;

    RegressionSummary(void)
        : experimentLabel("")
        , baselineValidationId("")
        , currentValidationId("")
        , totalChecks(0)
        , passedChecks(0)
        , warnedChecks(0)
        , failedChecks(0)
        , insufficientChecks(0)
        , compared(0)
        , completedSuccessfully(false)
    {}
};

#endif
