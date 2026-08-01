#include "../Entry/Validators/DirectionValidator.mqh"
#include "../Entry/Validators/ConfluenceValidator.mqh"
#include "../Entry/Validators/FreshnessValidator.mqh"
#include "../Entry/Validators/SpreadValidator.mqh"
#include "../Entry/Validators/SessionValidator.mqh"
#include "../Entry/Validators/DistanceValidator.mqh"
#include "../Entry/Validators/CooldownValidator.mqh"
#include "../Entry/Validators/RiskValidator.mqh"
#include "../Entry/Validators/ValidatorConfig.mqh"
#include "../Entry/EntryOrchestrator.mqh"
#include "../Tests/utils/MockValidator.mqh"
#include "../Tests/utils/MockTradeStateProvider.mqh"
#include "../Tests/utils/MockRiskEvaluator.mqh"
#include "BenchmarkTypes.mqh"

ConfluenceResult MakeBenchResult()
{
    ConfluenceResult r;
    r.valid = true;
    r.totalConfidence = 80.0;
    r.direction = CONFLUENCE_BULLISH;
    r.componentCount = 3;
    return r;
}

EntryContext MakeBenchContext()
{
    EntryContext ctx;
    ctx.spread = 10.0;
    ctx.now = 0;
    ctx.currentBid = 1.1000;
    ctx.currentAsk = 1.1002;
    ctx.barsSinceSignal = 2;
    ctx.candidateEntryPrice = 1.1001;
    return ctx;
}

int RunEntryBenchmarks(string &lines[], int &lineIdx)
{
    int totalBenchmarks = 0;

    SUITE_BENCH("Entry Engine Benchmarks");

    int warmup = BENCH_WARMUP;
    int measured = BENCH_MEASURED;

    ConfluenceResult benchResult = MakeBenchResult();
    EntryContext benchCtx = MakeBenchContext();

    // ─── 1. DirectionValidator ──────────────────────────────────────
    {
        CDirectionValidator v;
        string label = "Entry.DirectionValidator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            EntryFilterResult out;
            ulong t0 = GetMicrosecondCount();
            v.Validate(benchResult, benchCtx, out);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 2. ConfluenceValidator ─────────────────────────────────────
    {
        CConfluenceValidator v;
        string label = "Entry.ConfluenceValidator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            EntryFilterResult out;
            ulong t0 = GetMicrosecondCount();
            v.Validate(benchResult, benchCtx, out);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 3. FreshnessValidator ──────────────────────────────────────
    {
        CFreshnessValidator v;
        string label = "Entry.FreshnessValidator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            EntryFilterResult out;
            ulong t0 = GetMicrosecondCount();
            v.Validate(benchResult, benchCtx, out);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 4. SpreadValidator ─────────────────────────────────────────
    {
        CSpreadValidator v;
        string label = "Entry.SpreadValidator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            EntryFilterResult out;
            ulong t0 = GetMicrosecondCount();
            v.Validate(benchResult, benchCtx, out);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 5. SessionValidator ────────────────────────────────────────
    {
        CSessionValidator v;
        string label = "Entry.SessionValidator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            EntryFilterResult out;
            ulong t0 = GetMicrosecondCount();
            v.Validate(benchResult, benchCtx, out);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 6. DistanceValidator ───────────────────────────────────────
    {
        CDistanceValidator v;
        string label = "Entry.DistanceValidator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            EntryFilterResult out;
            ulong t0 = GetMicrosecondCount();
            v.Validate(benchResult, benchCtx, out);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 7. CooldownValidator ───────────────────────────────────────
    {
        CMockTradeStateProvider provider;
        provider.SetBarsSinceLastTrade(10);
        CCooldownValidator v(&provider);
        string label = "Entry.CooldownValidator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            EntryFilterResult out;
            ulong t0 = GetMicrosecondCount();
            v.Validate(benchResult, benchCtx, out);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 8. RiskValidator ───────────────────────────────────────────
    {
        CMockRiskEvaluator risk;
        risk.SetAllowed(true);
        risk.SetMaxLots(1.0);
        CRiskValidator v(&risk);
        string label = "Entry.RiskValidator";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            EntryFilterResult out;
            ulong t0 = GetMicrosecondCount();
            v.Validate(benchResult, benchCtx, out);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 9. Orchestrator: Empty registry ────────────────────────────
    {
        string label = "Entry.OrchestratorEmpty";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            CEntryOrchestrator orch;
            orch.Init();

            ulong t0 = GetMicrosecondCount();
            EntryDecision d = orch.Evaluate(benchResult, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);
            ulong t1 = GetMicrosecondCount();

            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 10. Orchestrator: Single validator ─────────────────────────
    {
        string label = "Entry.OrchestratorSingle";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            CEntryOrchestrator orch;
            orch.Init();
            CMockValidator mv("Mock", FILTER_PASS);
            orch.RegisterValidator(&mv);

            ulong t0 = GetMicrosecondCount();
            EntryDecision d = orch.Evaluate(benchResult, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);
            ulong t1 = GetMicrosecondCount();

            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 11. Orchestrator: All PASS (8 validators) ──────────────────
    {
        string label = "Entry.OrchestratorAllPass";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            CEntryOrchestrator orch;
            orch.Init();

            CMockValidator v1("V1", FILTER_PASS);
            CMockValidator v2("V2", FILTER_PASS);
            CMockValidator v3("V3", FILTER_PASS);
            CMockValidator v4("V4", FILTER_PASS);
            CMockValidator v5("V5", FILTER_PASS);
            CMockValidator v6("V6", FILTER_PASS);
            CMockValidator v7("V7", FILTER_PASS);
            CMockValidator v8("V8", FILTER_PASS);

            orch.RegisterValidator(&v1);
            orch.RegisterValidator(&v2);
            orch.RegisterValidator(&v3);
            orch.RegisterValidator(&v4);
            orch.RegisterValidator(&v5);
            orch.RegisterValidator(&v6);
            orch.RegisterValidator(&v7);
            orch.RegisterValidator(&v8);

            ulong t0 = GetMicrosecondCount();
            EntryDecision d = orch.Evaluate(benchResult, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);
            ulong t1 = GetMicrosecondCount();

            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    // ─── 12. Orchestrator: Early FAIL (3rd of 8) ────────────────────
    {
        string label = "Entry.OrchestratorEarlyFail";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 1, "evaluations");

        for(int run = 0; run < warmup + measured; run++)
        {
            CEntryOrchestrator orch;
            orch.Init();

            CMockValidator v1("V1", FILTER_PASS);
            CMockValidator v2("V2", FILTER_PASS);
            CMockValidator v3("V3", FILTER_FAIL);
            CMockValidator v4("V4", FILTER_PASS);
            CMockValidator v5("V5", FILTER_PASS);
            CMockValidator v6("V6", FILTER_PASS);
            CMockValidator v7("V7", FILTER_PASS);
            CMockValidator v8("V8", FILTER_PASS);

            orch.RegisterValidator(&v1);
            orch.RegisterValidator(&v2);
            orch.RegisterValidator(&v3);
            orch.RegisterValidator(&v4);
            orch.RegisterValidator(&v5);
            orch.RegisterValidator(&v6);
            orch.RegisterValidator(&v7);
            orch.RegisterValidator(&v8);

            ulong t0 = GetMicrosecondCount();
            EntryDecision d = orch.Evaluate(benchResult, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);
            ulong t1 = GetMicrosecondCount();

            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute()) { br.PrintResult(); lines[lineIdx] = br.ToBaselineLine(); lineIdx++; totalBenchmarks++; }
    }

    SUITE_BENCH_END("Entry Engine Benchmarks");
    return totalBenchmarks;
}
