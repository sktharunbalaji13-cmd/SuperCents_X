//+------------------------------------------------------------------+
//|                                       CalibrationReport.mqh        |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 16.1 (v3.0)     |
//+------------------------------------------------------------------+
//  Confidence measurement baseline (Sprint 16.1A, measurement only).
//  Produces the reliability histogram + ECE/MCE/Brier over the stored
//  telemetry, with NO score transforms applied.
//
//  Definitions (frozen by the baseline):
//    - Binning key: row.confidence (0-1), the exact value ReplayDecision
//      gates on.
//    - Bins are [lo, hi); the final bin is inclusive of hi.
//      binSize 0.05 -> 21 bins over [0, 1].
//    - Settled = WIN | LOSS | BREAKEVEN.  UNKNOWN rows are excluded from
//      the histogram entirely.
//    - winRate = wins / (wins + losses).  Scratches (incl. BREAKEVEN)
//      count in bin.trades but not in winRate.
//    - ECE/MCE weight each populated bin by bin.trades / decidedRows.
//    - Brier is over WIN/LOSS rows only (binary event win/loss).
//
//  Conservation invariant (regression-tested):
//      sum(bin.trades) == CalibrationSummary.decidedRows
//+------------------------------------------------------------------+
#ifndef __CALIBRATION_REPORT_MQH__
#define __CALIBRATION_REPORT_MQH__

#include "../Telemetry/TelemetryTypes.mqh"
#include "CalibrationMetrics.mqh"

#define CALIB_REPORT_DEFAULT_BIN_SIZE  0.05
#define CALIB_REPORT_MAX_BINS          33
#define CALIB_UNDERPOPULATED_THRESHOLD 30

//--- One reliability bin over the confidence range.
struct CalibrationBin
{
    double binLo;
    double binHi;
    double center;      // bin midpoint = expected win rate if perfectly calibrated
    int    trades;      // settled rows in bin (WIN + LOSS + BREAKEVEN)
    int    wins;
    int    losses;
    int    scratches;
    double winRate;     // wins / (wins + losses)
    double expected;    // == center
    double absError;    // |winRate - expected|
    double expectancy;  // mean R per trade (per-bin TradeStats)
    double profitFactor;
    double maxDrawdown;

    CalibrationBin(void)
        : binLo(0.0)
        , binHi(0.0)
        , center(0.0)
        , trades(0)
        , wins(0)
        , losses(0)
        , scratches(0)
        , winRate(0.0)
        , expected(0.0)
        , absError(0.0)
        , expectancy(0.0)
        , profitFactor(0.0)
        , maxDrawdown(0.0)
    {}
};

//--- Aggregate calibration metrics over the whole dataset.
struct CalibrationSummary
{
    int    totalRows;         // rows fed into the analysis
    int    decidedRows;       // settled rows (= sum of bin trades)
    int    binCount;          // populated bins
    int    underpopulatedBins;// bins with < CALIB_UNDERPOPULATED_THRESHOLD trades
    double binSize;
    double brier;             // mean squared error over WIN/LOSS rows
    double ece;               // expected calibration error
    double mce;               // max calibration error
    double confMin;
    double confMax;
    double confMean;
    double confP50;
    double confP90;

    CalibrationSummary(void)
        : totalRows(0)
        , decidedRows(0)
        , binCount(0)
        , underpopulatedBins(0)
        , binSize(CALIB_REPORT_DEFAULT_BIN_SIZE)
        , brier(0.0)
        , ece(0.0)
        , mce(0.0)
        , confMin(0.0)
        , confMax(0.0)
        , confMean(0.0)
        , confP50(0.0)
        , confP90(0.0)
    {}
};

//--- A row is part of the measurement set iff it has a settled outcome.
bool CalibrationIsSettled(const TelemetryRow &row)
{
    return (row.outcome == (int)TELEMETRY_OUTCOME_WIN ||
            row.outcome == (int)TELEMETRY_OUTCOME_LOSS ||
            row.outcome == (int)TELEMETRY_OUTCOME_BREAKEVEN);
}

//--- Bin index for a confidence value.  The epsilon absorbs floating-point
//    rounding at bin boundaries (e.g. 0.60 / 0.05 == 11.9999... in binary)
//    so exact boundary values land in the higher bin, per [lo, hi).
int CalibrationBinIndexOf(double c, double binSize, int maxBins)
{
    if(c < 0.0) c = 0.0;
    if(c > 1.0) c = 1.0;
    int idx = (int)(c / binSize + 1e-9);
    if(idx >= maxBins)
        idx = maxBins - 1;
    if(idx < 0)
        idx = 0;
    return idx;
}

//--- Build the confidence histogram + per-bin stats.  Only settled rows
//    enter the histogram; per-bin stats reuse CalibrationComputeStats so
//    expectancy/PF/maxDD semantics match the rest of the stack.
void CalibrationBuildBins(TelemetryRow &rows[], int count, double binSize,
                          CalibrationBin &bins[], int &binCount)
{
    ArrayResize(bins, 0);
    binCount = 0;

    int maxBins = (int)MathCeil(1.0 / binSize) + 1;
    if(maxBins > CALIB_REPORT_MAX_BINS)
        maxBins = CALIB_REPORT_MAX_BINS;

    ArrayResize(bins, maxBins);
    for(int i = 0; i < maxBins; i++)
    {
        bins[i] = CalibrationBin();
        bins[i].binLo = i * binSize;
        bins[i].binHi = MathMin((i + 1) * binSize, 1.0);
        bins[i].center = (bins[i].binLo + bins[i].binHi) / 2.0;
        bins[i].expected = bins[i].center;
    }

    bool eligible[];
    ArrayResize(eligible, count);

    for(int i = 0; i < count; i++)
    {
        if(!CalibrationIsSettled(rows[i]))
            continue;
        bins[CalibrationBinIndexOf(rows[i].confidence, binSize, maxBins)].trades++;
    }

    for(int i = 0; i < maxBins; i++)
    {
        if(bins[i].trades == 0)
            continue;

        binCount++;
        bool binEligible[];
        ArrayResize(binEligible, count);
        for(int k = 0; k < count; k++)
            binEligible[k] = CalibrationIsSettled(rows[k]) &&
                             (CalibrationBinIndexOf(rows[k].confidence, binSize, maxBins) == i);

        TradeStats stats;
        CalibrationComputeStats(rows, binEligible, count, stats);
        bins[i].wins = stats.wins;
        bins[i].losses = stats.losses;
        bins[i].scratches = stats.scratches;
        bins[i].winRate = stats.winRate;
        bins[i].expectancy = stats.expectancy;
        bins[i].profitFactor = stats.profitFactor;
        bins[i].maxDrawdown = stats.maxDrawdown;
        bins[i].absError = MathAbs(bins[i].winRate - bins[i].expected);
    }
}

//--- Brier score over WIN/LOSS rows only (binary event win/loss).
double CalibrationComputeBrier(TelemetryRow &rows[], int count)
{
    double sum = 0.0;
    int n = 0;
    for(int i = 0; i < count; i++)
    {
        double y = 0.0;
        if(rows[i].outcome == (int)TELEMETRY_OUTCOME_WIN)
            y = 1.0;
        else if(rows[i].outcome == (int)TELEMETRY_OUTCOME_LOSS)
            y = 0.0;
        else
            continue;
        double d = rows[i].confidence - y;
        sum += d * d;
        n++;
    }
    return (n > 0) ? sum / (double)n : 0.0;
}

//--- Confidence distribution stats over all rows (min/max/mean/p50/p90).
void CalibrationConfidenceStats(TelemetryRow &rows[], int count, CalibrationSummary &summary)
{
    if(count <= 0)
        return;

    double confs[];
    ArrayResize(confs, count);
    double mean = 0.0;
    for(int i = 0; i < count; i++)
    {
        confs[i] = rows[i].confidence;
        mean += confs[i];
    }
    summary.confMean = mean / (double)count;

    ArraySort(confs);
    summary.confMin = confs[0];
    summary.confMax = confs[count - 1];
    summary.confP50 = confs[(int)(0.5 * (count - 1))];
    summary.confP90 = confs[(int)(0.9 * (count - 1))];
}

//--- One-call analysis entry point: bins + summary metrics.
//    Conservation invariant: sum(bin.trades) == summary.decidedRows.
void CalibrationAnalyze(TelemetryRow &rows[], int count, double binSize,
                        CalibrationBin &bins[], int &binCount,
                        CalibrationSummary &summary)
{
    summary = CalibrationSummary();
    summary.totalRows = count;
    summary.binSize = binSize;

    CalibrationBuildBins(rows, count, binSize, bins, binCount);
    summary.brier = CalibrationComputeBrier(rows, count);
    CalibrationConfidenceStats(rows, count, summary);

    for(int i = 0; i < ArraySize(bins); i++)
    {
        if(bins[i].trades == 0)
            continue;
        summary.binCount++;
        summary.decidedRows += bins[i].trades;
        if(bins[i].trades < CALIB_UNDERPOPULATED_THRESHOLD)
            summary.underpopulatedBins++;
        summary.ece += bins[i].trades * bins[i].absError;
        if(bins[i].absError > summary.mce)
            summary.mce = bins[i].absError;
    }
    if(summary.decidedRows > 0)
        summary.ece /= (double)summary.decidedRows;
}

#endif
