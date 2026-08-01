//+------------------------------------------------------------------+
//|                                     CalibrationTransforms.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 16.2 (v3.0)     |
//+------------------------------------------------------------------+
//  Branch A confidence transforms (Sprint 16.2).  Every model is fitted
//  on the SAME settled rows and evaluated against the frozen v1
//  baseline (docs/Sprint16_1_Measurement.md).  Research objects only —
//  the production score is never modified.
//
//  Models:
//    CALIB_TRANSFORM_ISOTONIC_V1   - PAV isotonic regression (nonparametric)
//    CALIB_TRANSFORM_PLATT_V1      - sigmoid(a*conf + b), IRLS fit
//    CALIB_TRANSFORM_TEMPERATURE_V1- sigmoid((logit(conf) + b)/T), GD fit
//
//  Fit set: WIN/LOSS rows only (scratches and UNKNOWN excluded), the
//  same subset the baseline winRate/Brier use.
//
//  Reproducibility: every fit is deterministic (fixed iteration counts,
//  fixed accumulation order) and fully described by its serialized
//  parameters, so a fitted model can be re-applied from the manifest
//  without the training data (invertible transform of the input score).
//+------------------------------------------------------------------+
#ifndef __CALIBRATION_TRANSFORMS_MQH__
#define __CALIBRATION_TRANSFORMS_MQH__

#include "../Telemetry/TelemetryTypes.mqh"
#include "CalibrationMetrics.mqh"

#define CALIB_TRANSFORM_MAX_NODES  8192
#define CALIB_TRANSFORM_CLAMP      1.0e-9   // logit/sigmoid guard

enum ENUM_CALIB_TRANSFORM
{
    CALIB_TRANSFORM_RAW = 0,
    CALIB_TRANSFORM_ISOTONIC_V1,
    CALIB_TRANSFORM_PLATT_V1,
    CALIB_TRANSFORM_TEMPERATURE_V1
};

//--- Fitted model parameters (fully versioned, serializable).
struct CalibrationTransformParams
{
    int      type;          // ENUM_CALIB_TRANSFORM
    double   a;             // platt slope
    double   b;             // platt/temperature bias
    double   t;             // temperature log-scale (T = exp(t))
    double   minConf;       // fit support: apply clamps below this
    double   maxConf;       // fit support: apply clamps above this
    double   nodesX[];      // isotonic knots (sorted, non-decreasing y)
    double   nodesY[];
    int      nodeCount;
    bool     valid;

    CalibrationTransformParams(void)
        : type(CALIB_TRANSFORM_RAW)
        , a(0.0)
        , b(0.0)
        , t(0.0)
        , minConf(0.0)
        , maxConf(1.0)
        , nodeCount(0)
        , valid(false)
    {}
};

//--- Win/Loss rows are the fit/evaluation set (scratches excluded).
bool CalibrationIsWinLoss(const TelemetryRow &row)
{
    return (row.outcome == (int)TELEMETRY_OUTCOME_WIN ||
            row.outcome == (int)TELEMETRY_OUTCOME_LOSS);
}

string CalibrationTransformName(int type)
{
    switch(type)
    {
        case CALIB_TRANSFORM_RAW:             return "raw";
        case CALIB_TRANSFORM_ISOTONIC_V1:     return "isotonic_v1";
        case CALIB_TRANSFORM_PLATT_V1:        return "platt_v1";
        case CALIB_TRANSFORM_TEMPERATURE_V1:  return "temperature_v1";
    }
    return "unknown";
}

double CalibrationSigmoid(double x)
{
    if(x > 30.0) return 1.0;
    if(x < -30.0) return 0.0;
    return 1.0 / (1.0 + MathExp(-x));
}

double CalibrationLogit(double p)
{
    if(p < CALIB_TRANSFORM_CLAMP) p = CALIB_TRANSFORM_CLAMP;
    if(p > 1.0 - CALIB_TRANSFORM_CLAMP) p = 1.0 - CALIB_TRANSFORM_CLAMP;
    return MathLog(p / (1.0 - p));
}

//--- Apply a fitted model to one confidence value.  Always [0, 1].
double CalibrationTransformApply(double conf, const CalibrationTransformParams &p)
{
    if(!p.valid)
        return conf;
    if(conf < 0.0) conf = 0.0;
    if(conf > 1.0) conf = 1.0;

    double out = conf;
    switch(p.type)
    {
        case CALIB_TRANSFORM_RAW:
            break;

        case CALIB_TRANSFORM_ISOTONIC_V1:
        {
            if(p.nodeCount <= 0)
            {
                out = conf;
                break;
            }
            if(conf <= p.nodesX[0])
                out = p.nodesY[0];
            else if(conf >= p.nodesX[p.nodeCount - 1])
                out = p.nodesY[p.nodeCount - 1];
            else
            {
                int hi = p.nodeCount - 1;
                int lo = 0;
                while(hi - lo > 1)
                {
                    int mid = (lo + hi) / 2;
                    if(p.nodesX[mid] <= conf)
                        lo = mid;
                    else
                        hi = mid;
                }
                out = p.nodesY[lo];
            }
            break;
        }

        case CALIB_TRANSFORM_PLATT_V1:
            out = CalibrationSigmoid(p.a * conf + p.b);
            break;

        case CALIB_TRANSFORM_TEMPERATURE_V1:
            out = CalibrationSigmoid((CalibrationLogit(conf) + p.b) / MathExp(p.t));
            break;
    }

    if(out < 0.0) out = 0.0;
    if(out > 1.0) out = 1.0;
    return out;
}

//--- Deterministic merge sort on an int index array (parallel keys).
void CalibrationSortIndices(const double &keys[], int &idx[], int lo, int hi)
{
    if(hi - lo <= 1)
        return;
    int mid = (lo + hi) / 2;
    CalibrationSortIndices(keys, idx, lo, mid);
    CalibrationSortIndices(keys, idx, mid, hi);

    int tmp[];
    ArrayResize(tmp, hi - lo);
    int i = lo;
    int j = mid;
    int k = 0;
    while(i < mid && j < hi)
    {
        if(keys[idx[i]] <= keys[idx[j]])
            tmp[k++] = idx[i++];
        else
            tmp[k++] = idx[j++];
    }
    while(i < mid) tmp[k++] = idx[i++];
    while(j < hi)  tmp[k++] = idx[j++];
    for(int m = 0; m < k; m++)
        idx[lo + m] = tmp[m];
}

//--- Fit isotonic regression (PAV) on WIN/LOSS rows.
//    Groups are unique confidence values; ties are pooled.  Output is a
//    non-decreasing step function over the observed confidence range.
bool CalibrationFitIsotonic(TelemetryRow &rows[], int count, CalibrationTransformParams &p)
{
    p = CalibrationTransformParams();
    p.type = CALIB_TRANSFORM_ISOTONIC_V1;

    double confs[];
    double ys[];
    int n = 0;
    ArrayResize(confs, count);
    ArrayResize(ys, count);

    for(int i = 0; i < count; i++)
    {
        if(!CalibrationIsWinLoss(rows[i]))
            continue;
        confs[n] = rows[i].confidence;
        ys[n] = (rows[i].outcome == (int)TELEMETRY_OUTCOME_WIN) ? 1.0 : 0.0;
        n++;
    }
    if(n < 1)
        return false;

    int idx[];
    ArrayResize(idx, n);
    for(int i = 0; i < n; i++)
        idx[i] = i;
    CalibrationSortIndices(confs, idx, 0, n);

    //--- Collapse ties into groups (conf, y = winRate, w = wins+losses).
    double gx[];
    double gy[];
    double gw[];
    int ng = 0;
    ArrayResize(gx, n);
    ArrayResize(gy, n);
    ArrayResize(gw, n);

    for(int k = 0; k < n; k++)
    {
        int i = idx[k];
        if(ng > 0 && MathAbs(gx[ng - 1] - confs[i]) < 1e-12)
        {
            double w = gw[ng - 1];
            gy[ng - 1] = (gy[ng - 1] * w + ys[i]) / (w + 1.0);
            gw[ng - 1] = w + 1.0;
        }
        else
        {
            gx[ng] = confs[i];
            gy[ng] = ys[i];
            gw[ng] = 1.0;
            ng++;
        }
    }
    if(ng < 1)
        return false;

    //--- PAV: merge adjacent blocks that violate monotone non-decreasing.
    int blockCount = 0;
    double bx[];
    double by[];
    double bw[];
    ArrayResize(bx, ng);
    ArrayResize(by, ng);
    ArrayResize(bw, ng);

    for(int g = 0; g < ng; g++)
    {
        bx[blockCount] = gx[g];
        by[blockCount] = gy[g];
        bw[blockCount] = gw[g];
        blockCount++;

        while(blockCount >= 2 && by[blockCount - 1] < by[blockCount - 2])
        {
            double w1 = bw[blockCount - 2];
            double w2 = bw[blockCount - 1];
            bw[blockCount - 2] = w1 + w2;
            by[blockCount - 2] = (by[blockCount - 2] * w1 + by[blockCount - 1] * w2) / (w1 + w2);
            blockCount--;
        }
    }

    //--- Expose the left boundary of each block as a knot.
    int kc = 0;
    double kx[];
    double ky[];
    ArrayResize(kx, blockCount);
    ArrayResize(ky, blockCount);

    for(int b = 0; b < blockCount; b++)
    {
        //--- Find the first original group of this block for the x knot.
        double x = bx[b];
        if(kc == 0 || MathAbs(kx[kc - 1] - x) > 1e-12)
        {
            kx[kc] = x;
            ky[kc] = by[b];
            kc++;
        }
    }

    p.minConf = kx[0];
    p.maxConf = kx[kc - 1];
    p.nodeCount = kc;
    ArrayResize(p.nodesX, kc);
    ArrayResize(p.nodesY, kc);
    for(int k = 0; k < kc; k++)
    {
        p.nodesX[k] = kx[k];
        p.nodesY[k] = ky[k];
    }
    p.valid = true;
    return true;
}

//--- Fit Platt scaling: p = sigmoid(a*conf + b) by IRLS on WIN/LOSS rows.
//    Degenerate input (fewer than 2 distinct confidences) falls back to a
//    bias-only model p = sigmoid(b) = empirical win rate, which is the
//    best any monotone-in-x model can do on such data.
bool CalibrationFitPlatt(TelemetryRow &rows[], int count, CalibrationTransformParams &p)
{
    p = CalibrationTransformParams();
    p.type = CALIB_TRANSFORM_PLATT_V1;

    double xs[];
    int n = 0;
    double winSum = 0.0;
    ArrayResize(xs, count);
    for(int i = 0; i < count; i++)
    {
        if(!CalibrationIsWinLoss(rows[i]))
            continue;
        xs[n] = rows[i].confidence;
        if(rows[i].outcome == (int)TELEMETRY_OUTCOME_WIN)
            winSum += 1.0;
        n++;
    }
    if(n < 1)
        return false;

    ArrayResize(xs, n);
    ArraySort(xs);
    int distinct = 1;
    for(int i = 1; i < n; i++)
    {
        if(xs[i] > xs[i - 1] + 1e-12)
            distinct++;
    }
    if(distinct < 2)
    {
        p.a = 0.0;
        p.b = CalibrationLogit(winSum / (double)n);
        p.valid = true;
        return true;
    }

    double a = 1.0;
    double b = 0.0;

    for(int iter = 0; iter < 100; iter++)
    {
        double g0 = 0.0;   // dNLL/da
        double g1 = 0.0;   // dNLL/db
        double h00 = 0.0;
        double h01 = 0.0;
        double h11 = 0.0;

        for(int i = 0; i < count; i++)
        {
            if(!CalibrationIsWinLoss(rows[i]))
                continue;
            double x = rows[i].confidence;
            double y = (rows[i].outcome == (int)TELEMETRY_OUTCOME_WIN) ? 1.0 : 0.0;
            double pr = CalibrationSigmoid(a * x + b);
            double d = pr - y;
            double w = pr * (1.0 - pr);
            g0 += d * x;
            g1 += d;
            h00 += w * x * x;
            h01 += w * x;
            h11 += w;
        }

        double det = h00 * h11 - h01 * h01;
        if(det < 1e-12)
            break;
        double da = -(g0 * h11 - g1 * h01) / det;
        double db = -(h00 * g1 - h01 * g0) / det;
        a += da;
        b += db;
        if(MathAbs(da) < 1e-9 && MathAbs(db) < 1e-9)
            break;
    }

    p.a = a;
    p.b = b;
    p.t = 0.0;
    p.valid = true;
    return true;
}

//--- Fit temperature scaling: p = sigmoid((logit(conf) + b)/T), T = exp(t),
//    by gradient descent (NLL is not linear in t, so no IRLS).
bool CalibrationFitTemperature(TelemetryRow &rows[], int count, CalibrationTransformParams &p)
{
    p = CalibrationTransformParams();
    p.type = CALIB_TRANSFORM_TEMPERATURE_V1;

    int n = 0;
    for(int i = 0; i < count; i++)
    {
        if(CalibrationIsWinLoss(rows[i]))
            n++;
    }
    if(n < 2)
        return false;

    double b = 0.0;
    double t = 0.0;              // T = 1
    double lr = 0.1;
    const int ITERS = 3000;

    for(int iter = 0; iter < ITERS; iter++)
    {
        double gb = 0.0;
        double gt = 0.0;
        double invT = MathExp(-t);

        for(int i = 0; i < count; i++)
        {
            if(!CalibrationIsWinLoss(rows[i]))
                continue;
            double z = CalibrationLogit(rows[i].confidence);
            double y = (rows[i].outcome == (int)TELEMETRY_OUTCOME_WIN) ? 1.0 : 0.0;
            double s = (z + b) * invT;
            double pr = CalibrationSigmoid(s);
            double d = pr - y;
            gb += d * invT;
            gt += d * (-(z + b)) * invT;
        }

        b -= lr * gb;
        t -= lr * gt;
        lr *= 0.998;
    }

    p.a = 0.0;
    p.b = b;
    p.t = t;
    p.valid = true;
    return true;
}

//--- Fit a named model.  Dispatcher.
bool CalibrationFitTransform(int type, TelemetryRow &rows[], int count,
                             CalibrationTransformParams &p)
{
    switch(type)
    {
        case CALIB_TRANSFORM_ISOTONIC_V1:
            return CalibrationFitIsotonic(rows, count, p);
        case CALIB_TRANSFORM_PLATT_V1:
            return CalibrationFitPlatt(rows, count, p);
        case CALIB_TRANSFORM_TEMPERATURE_V1:
            return CalibrationFitTemperature(rows, count, p);
    }
    return false;
}

//--- Serialize fitted parameters as key:value lines (versioned provenance).
void CalibrationTransformSerialize(const CalibrationTransformParams &p, string &lines[])
{
    ArrayResize(lines, 0);
    int n = 0;
    ArrayResize(lines, 8);

    lines[n++] = "confidenceModel: " + CalibrationTransformName(p.type);
    lines[n++] = StringFormat("a: %.12f", p.a);
    lines[n++] = StringFormat("b: %.12f", p.b);
    lines[n++] = StringFormat("t: %.12f", p.t);
    lines[n++] = StringFormat("minConf: %.12f", p.minConf);
    lines[n++] = StringFormat("maxConf: %.12f", p.maxConf);
    lines[n++] = StringFormat("nodeCount: %d", p.nodeCount);

    string x = "";
    string y = "";
    for(int k = 0; k < p.nodeCount; k++)
    {
        if(x != "") x += ",";
        if(y != "") y += ",";
        x += StringFormat("%.12f", p.nodesX[k]);
        y += StringFormat("%.12f", p.nodesY[k]);
    }
    lines[n++] = "nodesX: " + x;
    ArrayResize(lines, n + 1);
    lines[n++] = "nodesY: " + y;
    ArrayResize(lines, n);
}

//--- Deserialize (round-trip for provenance re-application).
bool CalibrationTransformDeserialize(const string &lines[], CalibrationTransformParams &p)
{
    p = CalibrationTransformParams();
    for(int i = 0; i < ArraySize(lines); i++)
    {
        string line = lines[i];
        StringTrimLeft(line);
        StringTrimRight(line);
        int colon = StringFind(line, ":");
        if(colon <= 0)
            continue;
        string key = StringSubstr(line, 0, colon);
        StringTrimLeft(key);
        StringTrimRight(key);
        string val = StringSubstr(line, colon + 1);
        StringTrimLeft(val);
        StringTrimRight(val);

        if(key == "confidenceModel")
        {
            string name = val;
            StringTrimLeft(name);
            StringTrimRight(name);
            if(name == "raw")                    p.type = CALIB_TRANSFORM_RAW;
            else if(name == "isotonic_v1")       p.type = CALIB_TRANSFORM_ISOTONIC_V1;
            else if(name == "platt_v1")          p.type = CALIB_TRANSFORM_PLATT_V1;
            else if(name == "temperature_v1")    p.type = CALIB_TRANSFORM_TEMPERATURE_V1;
        }
        else if(key == "a")          p.a = StringToDouble(val);
        else if(key == "b")          p.b = StringToDouble(val);
        else if(key == "t")          p.t = StringToDouble(val);
        else if(key == "minConf")    p.minConf = StringToDouble(val);
        else if(key == "maxConf")    p.maxConf = StringToDouble(val);
        else if(key == "nodeCount")  p.nodeCount = (int)StringToInteger(val);
        else if(key == "nodesX")
        {
            string parts[];
            int n = StringSplit(val, ',', parts);
            ArrayResize(p.nodesX, n);
            for(int k = 0; k < n; k++)
                p.nodesX[k] = StringToDouble(parts[k]);
        }
        else if(key == "nodesY")
        {
            string parts[];
            int n = StringSplit(val, ',', parts);
            ArrayResize(p.nodesY, n);
            for(int k = 0; k < n; k++)
                p.nodesY[k] = StringToDouble(parts[k]);
        }
    }
    p.valid = (p.type == CALIB_TRANSFORM_RAW) ||
              ((p.type == CALIB_TRANSFORM_ISOTONIC_V1) && (p.nodeCount > 0)) ||
              (p.type == CALIB_TRANSFORM_PLATT_V1) ||
              (p.type == CALIB_TRANSFORM_TEMPERATURE_V1);
    return p.valid;
}

#endif
