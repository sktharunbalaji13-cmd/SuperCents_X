#include "../Confluence/Evaluators/StructureEvaluator.mqh"
#include "../Confluence/Evaluators/TrendEvaluator.mqh"
#include "../Confluence/Evaluators/OrderBlockEvaluator.mqh"
#include "../Confluence/Evaluators/FVGEvaluator.mqh"
#include "../Confluence/Evaluators/LiquidityEvaluator.mqh"
#include "../Confluence/Evaluators/PremiumDiscountEvaluator.mqh"
#include "../Confluence/ConfluenceScoreCalculator.mqh"
#include "../Confluence/ConfluenceEngine.mqh"
#include "BenchmarkTypes.mqh"

int RunConfluenceBenchmarks(string &lines[], int &lineIdx)
{
    int totalBenchmarks = 0;

    SUITE_BENCH("Confluence Engine Benchmarks");

    int warmup = BENCH_WARMUP;
    int measured = BENCH_MEASURED;

    // Benchmark 1: StructureEvaluator
    {
        DetectionContext ctx;
        CStructureEvaluator eval;
        string label = "Confluence.StructureEvaluator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            ConfluenceComponentResult res;
            ulong t0 = GetMicrosecondCount();
            eval.Evaluate(ctx, res);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Benchmark 2: TrendEvaluator
    {
        DetectionContext ctx;
        CTrendEvaluator eval;
        string label = "Confluence.TrendEvaluator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            ConfluenceComponentResult res;
            ulong t0 = GetMicrosecondCount();
            eval.Evaluate(ctx, res);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Benchmark 3: OrderBlockEvaluator
    {
        DetectionContext ctx;
        COrderBlockEvaluator eval;
        string label = "Confluence.OrderBlockEvaluator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            ConfluenceComponentResult res;
            ulong t0 = GetMicrosecondCount();
            eval.Evaluate(ctx, res);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Benchmark 4: FVGEvaluator
    {
        DetectionContext ctx;
        CFVGEvaluator eval;
        string label = "Confluence.FVGEvaluator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            ConfluenceComponentResult res;
            ulong t0 = GetMicrosecondCount();
            eval.Evaluate(ctx, res);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Benchmark 5: LiquidityEvaluator
    {
        DetectionContext ctx;
        CLiquidityEvaluator eval;
        string label = "Confluence.LiquidityEvaluator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            ConfluenceComponentResult res;
            ulong t0 = GetMicrosecondCount();
            eval.Evaluate(ctx, res);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Benchmark 6: PremiumDiscountEvaluator
    {
        DetectionContext ctx;
        ctx.swingHigh = 110.0;
        ctx.swingLow = 90.0;
        ctx.currentPrice = 95.0;
        CPremiumDiscountEvaluator eval;
        string label = "Confluence.PremiumDiscountEvaluator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            ConfluenceComponentResult res;
            ulong t0 = GetMicrosecondCount();
            eval.Evaluate(ctx, res);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Benchmark 7: ScoreCalculator with 6 components
    {
        CConfluenceScoreCalculator calc;
        ConfluenceWeights w;
        calc.SetWeights(w);

        ConfluenceComponentResult comps[6];
        for(int i = 0; i < 6; i++)
        {
            comps[i].type = (ENUM_CONFLUENCE_COMPONENT)i;
            comps[i].score = 80.0;
            comps[i].explanation = "Standard confluence";
        }

        string label = "Confluence.ScoreCalculator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "calculations");

        for(int run = 0; run < warmup + measured; run++)
        {
            ConfluenceResult result;
            ulong t0 = GetMicrosecondCount();
            calc.Calculate(comps, 6, result);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Benchmark 8: ConfluenceEngine evaluator path (full Update)
    {
        CConfluenceEngine engine;
        engine.Init();

        CPremiumDiscountEvaluator pd;
        engine.RegisterEvaluator(&pd);
        engine.SetWeights(ConfluenceWeights());

        string label = "Confluence.EngineEvaluatorPath";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "updates");

        for(int run = 0; run < warmup + measured; run++)
        {
            ulong t0 = GetMicrosecondCount();
            engine.Update();
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Benchmark 9: ConfluenceEngine legacy rule path
    {
        CConfluenceEngine engine;
        engine.Init();

        string label = "Confluence.EngineRulePath";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "updates");

        for(int run = 0; run < warmup + measured; run++)
        {
            ulong t0 = GetMicrosecondCount();
            engine.Update();
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Benchmark 10: Evaluator registration cost
    {
        string label = "Confluence.RegisterEvaluators";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "registrations");

        for(int run = 0; run < warmup + measured; run++)
        {
            CConfluenceEngine engine;
            engine.Init();

            CStructureEvaluator se;
            CTrendEvaluator te;
            COrderBlockEvaluator ob;
            CFVGEvaluator fvg;
            CLiquidityEvaluator liq;
            CPremiumDiscountEvaluator pd;

            ulong t0 = GetMicrosecondCount();
            engine.RegisterEvaluator(&se);
            engine.RegisterEvaluator(&te);
            engine.RegisterEvaluator(&ob);
            engine.RegisterEvaluator(&fvg);
            engine.RegisterEvaluator(&liq);
            engine.RegisterEvaluator(&pd);
            ulong t1 = GetMicrosecondCount();

            engine.Shutdown();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    SUITE_BENCH_END("Confluence Engine Benchmarks");
    return totalBenchmarks;
}
