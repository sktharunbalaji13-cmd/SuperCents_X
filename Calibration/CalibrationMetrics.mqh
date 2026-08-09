//+------------------------------------------------------------------+
//|                                        CalibrationMetrics.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Shared offline replay metrics for the calibration optimizers.
//  All analysis runs on stored telemetry rows â€” no engine access needed.
//+------------------------------------------------------------------+
#ifndef __CALIBRATION_METRICS_MQH__
#define __CALIBRATION_METRICS_MQH__

#include "../Telemetry/TelemetryTypes.mqh"

#define CALIB_SCRATCH_EPS 0.05   // |R| below this is a scratch trade

double IncompleteBeta(double a, double b, double x);
double LnGamma(double x);

struct TradeStats
{
    int    trades;
    int    wins;
    int    losses;
    int    scratches;
    double grossProfit;
    double grossLoss;
    double profitFactor;
    double expectancy;      // mean R per trade
    double winRate;         // wins / (wins + losses)
    double netProfit;       // sum of R
    double maxDrawdown;     // R-units peak-to-trough
    double maxDrawdownPct;  // % of equity peak
    double recoveryFactor;  // netProfit / maxDrawdown

    TradeStats(void)
        : trades(0)
        , wins(0)
        , losses(0)
        , scratches(0)
        , grossProfit(0.0)
        , grossLoss(0.0)
        , profitFactor(0.0)
        , expectancy(0.0)
        , winRate(0.0)
        , netProfit(0.0)
        , maxDrawdown(0.0)
        , maxDrawdownPct(0.0)
        , recoveryFactor(0.0)
    {}
};

//--- Replay: do all validators except the confluence gate pass?
bool CalibrationOtherValidatorsPass(const TelemetryRow &row)
{
    for(int i = 0; i < row.validatorCount; i++)
    {
        if(row.validators[i].name == "ConfluenceValidator")
            continue;
        if(row.validators[i].result == FILTER_FAIL)
            return false;
    }
    return true;
}

//--- Replay: confluence gate + all other validators (skip one validator).
bool CalibrationReplayWithout(const TelemetryRow &row, double threshold, const string skipValidator)
{
    if(row.confidence < threshold)
        return false;
    for(int i = 0; i < row.validatorCount; i++)
    {
        if(row.validators[i].name == "ConfluenceValidator" ||
           row.validators[i].name == skipValidator)
            continue;
        if(row.validators[i].result == FILTER_FAIL)
            return false;
    }
    return true;
}

//--- Trade statistics over the eligible subset of rows.
//    eligible[i] true -> the row qualifies; only settled outcomes count.
void CalibrationComputeStats(TelemetryRow &rows[],
                             const bool &eligible[],
                             int count,
                             TradeStats &out)
{
    out = TradeStats();

    double equity = 0.0;
    double peak = 0.0;

    for(int i = 0; i < count; i++)
    {
        if(!eligible[i])
            continue;
        if(rows[i].outcome == (int)TELEMETRY_OUTCOME_UNKNOWN)
            continue;

        double r = rows[i].rMultiple;
        if(r > CALIB_SCRATCH_EPS)
        {
            out.wins++;
            out.grossProfit += r;
        }
        else if(r < -CALIB_SCRATCH_EPS)
        {
            out.losses++;
            out.grossLoss += -r;
        }
        else
        {
            out.scratches++;
        }
        out.trades++;

        equity += r;
        out.netProfit += r;
        if(equity > peak)
            peak = equity;
        double dd = peak - equity;
        if(dd > out.maxDrawdown)
            out.maxDrawdown = dd;
    }

    out.profitFactor = (out.grossLoss > 0.0)
        ? out.grossProfit / out.grossLoss
        : (out.grossProfit > 0.0 ? 99.0 : 0.0);
    out.expectancy = (out.trades > 0) ? out.netProfit / (double)out.trades : 0.0;
    int decided = out.wins + out.losses;
    out.winRate = (decided > 0) ? (double)out.wins / (double)decided : 0.0;
    out.maxDrawdownPct = (peak > 0.0) ? out.maxDrawdown / peak * 100.0 : 0.0;
    out.recoveryFactor = (out.maxDrawdown > 0.0)
        ? out.netProfit / out.maxDrawdown
        : (out.netProfit > 0.0 ? 99.0 : 0.0);
}

//--- Welch's two-sample t-test on rMultiples of two groups.
//    Returns p-value (two-tailed). Group sizes < 2 -> p = 1.0.
double CalibrationWelchPValue(const double &a[], int na, const double &b[], int nb)
{
    if(na < 2 || nb < 2)
        return 1.0;

    double ma = 0.0, mb = 0.0;
    for(int i = 0; i < na; i++) ma += a[i];
    for(int i = 0; i < nb; i++) mb += b[i];
    ma /= na;
    mb /= nb;

    double va = 0.0, vb = 0.0;
    for(int i = 0; i < na; i++) { double d = a[i] - ma; va += d * d; }
    for(int i = 0; i < nb; i++) { double d = b[i] - mb; vb += d * d; }
    va /= (na - 1);
    vb /= (nb - 1);

    double se = MathSqrt(va / na + vb / nb);
    if(se <= 0.0)
        return (ma == mb) ? 1.0 : 0.0;

    double t = (ma - mb) / se;

    //--- Degrees of freedom (Welch-Satterthwaite), clamped.
    double num = (va / na + vb / nb) * (va / na + vb / nb);
    double den = (va * va / (na * na * (na - 1))) + (vb * vb / (nb * nb * (nb - 1)));
    double df = (den > 0.0) ? num / den : (na + nb - 2);
    if(df < 1.0) df = 1.0;
    if(df > 1000.0) df = 1000.0;

    //--- Two-tailed Student's t survival function (approximation).
    double x = df / (df + t * t);
    double ib = IncompleteBeta(df / 2.0, 0.5, x);
    return ib;   // two-tailed p
}

//--- Regularized incomplete beta (Numerical Recipes betacf/betai).
double IncompleteBeta(double a, double b, double x)
{
    if(x <= 0.0) return 0.0;
    if(x >= 1.0) return 1.0;

    double lnBeta = 0.0;
    lnBeta += LnGamma(a + b) - LnGamma(a) - LnGamma(b);

    double front = MathExp(lnBeta + a * MathLog(x) + b * MathLog(1.0 - x)) / a;

    //--- Continued fraction (betacf).
    const int MAXIT = 200;
    const double EPS = 1.0e-12;
    const double FPMIN = 1.0e-300;

    double qab = a + b;
    double qap = a + 1.0;
    double qam = a - 1.0;
    double c = 1.0;
    double d = 1.0 - qab * x / qap;
    if(MathAbs(d) < FPMIN) d = FPMIN;
    d = 1.0 / d;
    double h = d;

    for(int m = 1; m <= MAXIT; m++)
    {
        int m2 = 2 * m;
        double aa = m * (b - m) * x / ((qam + m2) * (a + m2));
        d = 1.0 + aa * d;
        if(MathAbs(d) < FPMIN) d = FPMIN;
        c = 1.0 + aa / c;
        if(MathAbs(c) < FPMIN) c = FPMIN;
        d = 1.0 / d;
        h *= d * c;

        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
        d = 1.0 + aa * d;
        if(MathAbs(d) < FPMIN) d = FPMIN;
        c = 1.0 + aa / c;
        if(MathAbs(c) < FPMIN) c = FPMIN;
        d = 1.0 / d;
        double del = d * c;
        h *= del;

        if(MathAbs(del - 1.0) < EPS)
            break;
    }

    return front * h;
}

//--- Log-gamma (Lanczos approximation).
double LnGamma(double x)
{
    double cof[6] = { 76.18009172947146, -86.50532032941677,
                      24.01409824083091, -1.231739572450155,
                      0.1208650973866179e-2, -0.5395239384953e-5 };
    double y = x;
    double tmp = x + 5.5;
    tmp -= (x + 0.5) * MathLog(tmp);
    double ser = 1.000000000190015;
    for(int j = 0; j < 6; j++)
        ser += cof[j] / ++y;
    return -tmp + MathLog(2.5066282746310005 * ser / x);
}

#endif

