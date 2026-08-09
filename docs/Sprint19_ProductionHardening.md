# Sprint 19.0 — Production Hardening

**Target Version:** v2.1-production-hardening

---

## Architectural Charter

Sprint 19 transforms the platform from development-ready to production-ready.

It provides configuration management, operational resilience, diagnostics, and deployment validation without altering any trading, portfolio, optimization, or research behavior.

Production components supervise, validate, and recover — they never make trading decisions.

---

## Design Invariants

### Invariant 1 — Frozen Functional Platform

The following remain behaviorally frozen:

| Directory | Role |
|-----------|------|
| `Structure/` | Market structure detectors |
| `Confluence/` | Signal aggregation & scoring |
| `Entry/` | Decision, planning, risk, position lifecycle |
| `Trading/` | Order execution & validation |
| `Risk/` | Per-symbol risk management |
| `Portfolio/` | Multi-symbol orchestration & portfolio risk |
| `Monitoring/` | Event bus, metrics, health |
| `Optimization/` | Research & validation framework |

No functional changes. Zero lines of trading, risk, portfolio, or optimization logic are modified.

### Invariant 2 — Operational Separation

Production services may:

- validate
- monitor
- recover
- configure
- report

They shall not:

- generate entries
- alter risk calculations
- modify portfolio decisions
- rewrite optimization results

### Invariant 3 — Deterministic Startup

Given the same:

- configuration
- platform version
- market data

startup must produce the same initialized state every time.

### Invariant 4 — Fail Safe

Operational failures shall result in one of three deterministic outcomes:

1. **Continue safely** — non-critical fault logged, platform continues
2. **Suspend safely** — critical fault isolated, trading suspended, state preserved
3. **Terminate safely** — unrecoverable fault, platform shuts down with state archived

Never undefined behavior.

### Invariant 5 — Configuration Immutability

Once a trading session begins:

- runtime configuration becomes read-only
- changes require an explicit reload or restart
- no module may modify its own configuration during execution

---

## System Overview

The Production layer wraps the frozen platform in operational supervision.

```
+----------------------------------------------------------+
|                    Production Layer                        |
|  +-------------+  +-----------+  +-------------------+    |
|  | Config &    |  | Reliability|  | Diagnostics &     |   |
|  | Version Mgt |  | & Recovery |  | Observability     |   |
|  +-------------+  +-----------+  +-------------------+    |
|  +---------------------------------------------------+    |
|  | Deployment Validation                             |    |
|  +---------------------------------------------------+    |
+----------------------------------------------------------+
        |            |            |              |
        | validates  | supervises |  instruments  |
        v            v            v              v
+----------------------------------------------------------+
|              Frozen Functional Platform                    |
|  (Engine, Portfolio, Entry, Trading, Risk, Monitoring,    |
|   Optimization)                                           |
+----------------------------------------------------------+
```

Every arrow is supervisory. No arrow injects state into the functional platform.

---

## Directory Layout

```
Production/
    ProductionTypes.mqh         # Shared enums, structs, contracts
    ConfigManager.mqh           # Immutable configuration loading & validation
    VersionManager.mqh          # Platform version tracking & compatibility
    MigrationManager.mqh        # Schema/configuration migration support
    StartupValidator.mqh        # Deterministic startup state verification
    EnvironmentValidator.mqh    # Runtime environment & dependency checks
    FaultManager.mqh            # Fault classification & deterministic outcomes
    RecoveryManager.mqh         # Safe recovery & restart coordination
    HealthSupervisor.mqh        # Cross-module health aggregation
    DiagnosticEngine.mqh        # Structured diagnostic event producer
    LogExporter.mqh             # Production log formatting & export
    PerformanceProfiler.mqh     # Execution timing & throughput analysis
    DeploymentVerifier.mqh      # Release readiness verification
    ProductionReport.mqh        # Operational report assembly
```

Every module is a single `*.mqh` header. No subdirectories.

---

## Shared Types — `ProductionTypes.mqh`

### Enums

```cpp
enum ENUM_FAULT_SEVERITY
{
    FAULT_MINOR = 0,        // Continue safely
    FAULT_MAJOR,            // Suspend safely
    FAULT_CRITICAL          // Terminate safely
};

enum ENUM_CONFIG_STATUS
{
    CONFIG_VALID = 0,
    CONFIG_INCOMPLETE,
    CONFIG_VERSION_MISMATCH,
    CONFIG_CORRUPTED
};

enum ENUM_STARTUP_PHASE
{
    STARTUP_PHASE_CONFIG = 0,
    STARTUP_PHASE_DEPENDENCIES,
    STARTUP_PHASE_MODULES,
    STARTUP_PHASE_COMPLETE
};

enum ENUM_RECOVERY_ACTION
{
    RECOVERY_NONE = 0,
    RECOVERY_RESTART_MODULE,
    RECOVERY_RELOAD_CONFIG,
    RECOVERY_FULL_RESTART
};

enum ENUM_DEPLOYMENT_STATUS
{
    DEPLOYMENT_READY = 0,
    DEPLOYMENT_WARNING,
    DEPLOYMENT_BLOCKED
};
```

### Structs

```cpp
struct ConfigEntry
{
    string  key;
    string  value;
    string  section;
    bool    isRequired;
};

struct VersionInfo
{
    int     major;
    int     minor;
    int     patch;
    string  label;

    string ToString(void) const;
};

struct MigrationStep
{
    int          fromVersion;
    int          toVersion;
    string       description;
    bool         isBreaking;
};

struct StartupReport
{
    ENUM_STARTUP_PHASE  phase;
    bool                success;
    int                 moduleCount;
    int                 failedModules;
    string              failures[];
    ulong               elapsedUs;
};

struct FaultEvent
{
    datetime            timestamp;
    ENUM_FAULT_SEVERITY severity;
    string              sourceModule;
    string              description;
    ENUM_RECOVERY_ACTION recoveryAction;
    bool                recovered;
};

struct HealthStatus
{
    string              moduleName;
    bool                isOperational;
    ulong               uptimeUs;
    int                 warningCount;
    int                 faultCount;
    ENUM_FAULT_SEVERITY worstFault;
};

struct DeploymentReport
{
    ENUM_DEPLOYMENT_STATUS  status;
    int                     checksPassed;
    int                     checksFailed;
    string                  failures[];
    VersionInfo             platformVersion;
    datetime                validatedAt;
};
```

---

## Module Specifications

### 1. ConfigManager — `ConfigManager.mqh`

**Purpose:** Load, validate, and serve immutable configuration. Configuration is read-only after load.

**Interface:**

```cpp
class CConfigManager
{
public:
    bool Init(const string configFile);
    void Shutdown(void);
    bool IsInitialized(void) const;

    ENUM_CONFIG_STATUS GetStatus(void) const;

    bool GetString(const string key, string &outValue) const;
    bool GetInteger(const string key, int &outValue) const;
    bool GetDouble(const string key, double &outValue) const;
    bool GetBool(const string key, bool &outValue) const;

    bool HasKey(const string key) const;
    int  GetEntryCount(void) const;

    bool Reload(const string configFile);
    bool Validate(void) const;
    bool ExportSnapshot(const string filepath) const;
};
```

**Constraints:**
- Load once at startup. `Reload()` requires explicit call, never automatic.
- All getters are `const`. No setter methods exist after Init.
- `Validate()` checks required keys, type correctness, and version compatibility.

### 2. VersionManager — `VersionManager.mqh`

**Purpose:** Track platform version, verify compatibility across modules, enable migration awareness.

**Interface:**

```cpp
class CVersionManager
{
public:
    bool Init(const VersionInfo &platformVersion);
    void Shutdown(void);

    VersionInfo GetPlatformVersion(void) const;
    bool IsCompatible(const VersionInfo &other) const;
    bool RegisterModule(const string moduleName, const VersionInfo &version);
    bool GetModuleVersion(const string moduleName, VersionInfo &out) const;
    int  GetModuleCount(void) const;
};
```

**Constraints:**
- Platform version is set once and never modified.
- Compatibility is structural (major.minor), not cosmetic (patch).
- Configuration files carry an independent `configSchemaVersion` field.
- Config schema versions evolve independently of platform versions;
  migrations are driven by schema version, not platform version.

### 3. MigrationManager — `MigrationManager.mqh`

**Purpose:** Handle schema and configuration migration across version upgrades.
Schema version is tracked independently of platform version so that
configuration format evolves without requiring a platform release.

**Interface:**

```cpp
class CMigrationManager
{
public:
    bool Init(void);
    void Shutdown(void);

    bool RegisterStep(const MigrationStep &step);
    int  GetStepCount(void) const;

    bool NeedsMigration(const VersionInfo &fromVersion, const VersionInfo &toVersion) const;
    bool Execute(const VersionInfo &fromVersion, const VersionInfo &toVersion);
    bool Rollback(const VersionInfo &fromVersion, const VersionInfo &toVersion);
};
```

**Constraints:**
- Migration is forward-only. Rollback restores state but does not replay.
- Breaking migrations require explicit acknowledgement before execution.

### 4. StartupValidator — `StartupValidator.mqh`

**Purpose:** Verify deterministic startup state before the platform enters operational mode.

**Interface:**

```cpp
class CStartupValidator
{
public:
    bool Init(void);
    void Shutdown(void);

    bool ValidateConfig(void);
    bool ValidateDependencies(void);
    bool ValidateModules(void);

    StartupReport GenerateReport(void) const;
    bool IsStartupComplete(void) const;
};
```

**Constraints:**
- Runs before the main trading loop begins.
- Reports all failures; first failure does not prevent subsequent checks.
- Startup is not "complete" until all phases pass.

### 5. EnvironmentValidator — `EnvironmentValidator.mqh`

**Purpose:** Verify the runtime environment meets platform requirements.

**Checks:**
- Terminal version compatibility
- Account type validation (hedging/netting)
- Required symbol availability
- Data feed connectivity
- Disk space for logging
- Memory availability

**Interface:**

```cpp
class CEnvironmentValidator
{
public:
    bool Init(void);
    void Shutdown(void);

    bool CheckTerminalVersion(void);
    bool CheckAccountType(void);
    bool CheckSymbolAccess(const string symbols[]);
    bool CheckDataFeed(void);
    bool CheckDiskSpace(ulong minBytes);
    bool CheckMemory(ulong minBytes);

    bool ValidateAll(void);
};
```

**Constraints:**
- Pure validation — no state modification.
- Failures are reported; the caller decides the outcome.

### 6. FaultManager — `FaultManager.mqh`

**Purpose:** Classify operational faults and determine the prescribed deterministic outcome.

**Interface:**

```cpp
class CFaultManager
{
public:
    bool Init(void);
    void Shutdown(void);

    bool ReportFault(const string sourceModule,
                     const string description,
                     ENUM_FAULT_SEVERITY severity,
                     FaultEvent &outEvent);

    ENUM_RECOVERY_ACTION GetRecommendedAction(const FaultEvent &event) const;

    int GetFaultCount(void) const;
    int GetFaultCountBySeverity(ENUM_FAULT_SEVERITY severity) const;
    bool GetFaultHistory(FaultEvent &outHistory[]) const;
};
```

**Constraints:**
- Faults are recorded, never silenced.
- Recovery actions are recommendations — the caller executes them.
- Fault history is retained for the session lifetime.

### 7. RecoveryManager — `RecoveryManager.mqh`

**Purpose:** Execute safe recovery sequences based on fault classification.

**Interface:**

```cpp
class CRecoveryManager
{
public:
    bool Init(void);
    void Shutdown(void);

    bool Recover(const FaultEvent &event);
    bool RestartModule(const string moduleName);
    bool ReloadConfiguration(void);
    bool FullRestart(void);

    bool IsRecovering(void) const;
    int GetRecoveryCount(void) const;
};
```

**Constraints:**
- Recovery never creates or modifies trading state — only operational state.
- `FullRestart()` archives current state before initiating restart.

### 8. HealthSupervisor — `HealthSupervisor.mqh`

**Purpose:** Aggregate health status across all modules into a single observable state.

**Interface:**

```cpp
class CHealthSupervisor
{
public:
    bool Init(void);
    void Shutdown(void);

    bool RegisterModule(const string moduleName);
    bool UpdateStatus(const string moduleName, bool isOperational);
    bool ReportFault(const string moduleName, ENUM_FAULT_SEVERITY severity);

    HealthStatus GetModuleStatus(const string moduleName) const;
    bool GetAllStatuses(HealthStatus &outStatuses[]) const;

    int GetOperationalCount(void) const;
    int GetDegradedCount(void) const;
    int GetFailedCount(void) const;
};
```

**Constraints:**
- Pure aggregation — never interprets or acts on health data.
- Modules register themselves; unregistered modules are unknown.

### 9. DiagnosticEngine — `DiagnosticEngine.mqh`

**Purpose:** Produce structured diagnostic events from platform state.

**Interface:**

```cpp
class CDiagnosticEngine
{
public:
    bool Init(void);
    void Shutdown(void);

    bool EmitDiagnostic(const string source,
                        const string category,
                        const string message,
                        ulong value = 0);

    bool DumpState(const string filepath);
    bool GetDiagnosticLog(string &outLog) const;
    void Clear(void);
};
```

**Constraints:**
- Diagnostic engine never modifies platform state — only reads and records.
- Output is structured for both human and machine consumption.

### 10. LogExporter — `LogExporter.mqh`

**Purpose:** Format and export logs in production-standard formats.

**Interface:**

```cpp
class CLogExporter
{
public:
    bool Init(void);
    void Shutdown(void);

    bool SetLogLevel(ENUM_LOG_LEVEL level);
    bool ExportToFile(const string filepath);
    bool ExportToCSV(const string filepath);
    bool RotateLog(void);
    ulong GetLogSize(void) const;
};
```

**Constraints:**
- Consumes existing `CLogger` output — never duplicates logging.
- Rotation preserves the last N archives.

### 11. PerformanceProfiler — `PerformanceProfiler.mqh`

**Purpose:** Measure execution timing and throughput across the update cycle.

**Interface:**

```cpp
class CPerformanceProfiler
{
public:
    bool Init(void);
    void Shutdown(void);

    bool RecordTiming(const string label, ulong elapsedUs);
    bool GetAverageTiming(const string label, double &outAvgUs) const;
    bool GetMaxTiming(const string label, ulong &outMaxUs) const;

    bool Snapshot(PerformanceSnapshot &out) const;
    bool ExportProfile(const string filepath) const;
};
```

**Constraints:**
- Consumes existing `CMetricsCollector` data — no duplicate instrumentation.
- Profile snapshots are read-only copies.

### 12. DeploymentVerifier — `DeploymentVerifier.mqh`

**Purpose:** Verify the platform is ready for live deployment.

**Interface:**

```cpp
class CDeploymentVerifier
{
public:
    bool Init(void);
    void Shutdown(void);

    bool VerifyEnvironment(void);
    bool VerifyConfiguration(void);
    bool VerifyDependencies(void);
    bool VerifyStartup(void);

    DeploymentReport GenerateReport(void) const;
    ENUM_DEPLOYMENT_STATUS GetStatus(void) const;
};
```

**Constraints:**
- All verification methods are idempotent.
- `DEPLOYMENT_BLOCKED` status prevents the platform from entering operational mode.

### 13. ProductionReport — `ProductionReport.mqh`

**Purpose:** Assemble operational reports from all Production subsystems.

**Interface:**

```cpp
class CProductionReport
{
public:
    bool Init(void);
    void Shutdown(void);

    static string FormatStartupReport(const StartupReport &report);
    static string FormatHealthSummary(const HealthStatus &statuses[], int count);
    static string FormatDeploymentReport(const DeploymentReport &report);
    static string FormatFaultSummary(const FaultEvent &events[], int count);
};
```

**Constraints:**
- Pure formatting — no computation, no state access.
- All metric computation is performed by the source subsystem before formatting.

---

## Integration Rules

### Dependency Direction

```
Production
    |
    +---> Monitoring (EventBus, MetricsCollector, HealthMonitor)
    +---> Optimization (report schemas)
    +---> Core (Engine lifecycle, Config)
```

Production depends on stable interfaces only.

### Ownership Rule for Supervisory Consumers

Production modules may observe runtime state and emit diagnostics,
but they shall never retain ownership of runtime-managed resources
beyond the scope required for supervision.

### What Production Does NOT Integrate With

| Module | Reason |
|--------|--------|
| `Structure/` | Never validates market structure |
| `Confluence/` | Never reads signal state |
| `Entry/` | Never observes decisions |
| `Trading/` | Never touches order flow |
| `Risk/` | Never evaluates risk state |
| `Portfolio/` | Never inspects portfolio decisions |

### Lifecycle

```
1. EnvironmentValidator   — runtime environment checks
2. ConfigManager          — load & validate configuration
3. VersionManager         — verify platform & module versions
4. MigrationManager       — execute required migrations
5. StartupValidator       — validate all startup phases
6. DeploymentVerifier     — final release readiness check
         |
         v  (if all pass)
7. Platform enters operational mode
         |
8. HealthSupervisor       — continuous health aggregation
9. FaultManager           — fault classification during operation
10. RecoveryManager       — recovery when faults occur
11. DiagnosticEngine      — structured diagnostics
12. PerformanceProfiler   — timing & throughput
13. LogExporter           — production log output
```

### Shutdown Lifecycle

Shutdown is equally deterministic. The sequence:

```
Operational Mode
      |
      v
1. Drain          — complete in-flight operations, reject new requests
      |
      v
2. Flush Logs     — force-write all buffered log entries
      |
      v
3. Persist State  — archive diagnostics, fault history, performance profile
      |
      v
4. Release Resources  — close files, release handles, shutdown modules
      |
      v
5. Shutdown Complete — exit code set, termination safe
```

Every phase is observable. A shutdown that fails before completion produces a diagnostic archive
for post-mortem analysis.

---

## Acceptance Criteria

Sprint 19 is accepted when:

1. **Deterministic startup:** `CStartupValidator` confirms all phases pass given valid config. Same config always produces same initialized state.

2. **Configuration immutability:** After `CConfigManager::Init()`, all getters return stable values. No setter exists. Reload is explicit.

3. **Fault classification:** `CFaultManager` correctly classifies faults into MINOR/MAJOR/CRITICAL and recommends appropriate recovery action.

4. **Recovery isolation:** `CRecoveryManager` recovery actions never modify trading state — only operational state.

5. **Health aggregation:** `CHealthSupervisor` correctly aggregates status across all registered modules. Failed modules are observable.

6. **Deployment verification:** `CDeploymentVerifier` produces a `DeploymentReport` with actionable status. `DEPLOYMENT_BLOCKED` prevents operational mode.

7. **Zero new warnings:** Compilation adds no warnings beyond the 4 pre-existing `POSITION_COMMISSION` deprecation.

---

## Regression Strategy

| Test | How |
|------|-----|
| Compilation | 0 errors, ≤4 warnings both with and without `Production/` |
| Startup sequence | Run full startup pipeline with valid config; verify all phases pass |
| Startup with invalid config | Supply incomplete config; verify CONFIG_INCOMPLETE status |
| Fault simulation | Inject MINOR/MAJOR/CRITICAL faults; verify deterministic outcomes |
| Recovery isolation | Trigger recovery; verify trading state unchanged |
| Health aggregation | Register 3 modules with varying health; verify aggregate reflects all |
| Deployment block | Fail environment check; verify DEPLOYMENT_BLOCKED |
| Removability | Remove `Production/` directory; verify platform compiles and runs identically |

---

---

## Operational Principles

The following principles govern the Production layer.
They are not implementation guidance — they are operational philosophy.

1. **Startup is deterministic.** Given the same configuration, platform version, and data,
   startup always produces the same initialized state.

2. **Configuration is immutable during execution.** Once loaded, configuration becomes read-only.
   Changes require explicit reload or restart — never automatic.

3. **Recovery never modifies trading decisions.** Recovery actions restore operational state only.
   The trading platform's decision logic is never altered by recovery procedures.

4. **Diagnostics never change runtime behavior.** Diagnostic emission is observation-only.
   No diagnostic path may influence execution, risk, or portfolio outcomes.

5. **Version compatibility is explicit.** Every configuration carries a schema version.
   Compatibility is verified at load time, never assumed.

6. **Every failure is classified.** Unclassified failures are treated as CRITICAL by default.
   Classification enables deterministic recovery decisions.

7. **Every shutdown is graceful.** The shutdown sequence is defined, observable,
   and produces a diagnostic archive for post-mortem analysis if interrupted.

8. **Every production report is reproducible.** Given the same inputs and platform version,
   the same operational report must be produced. Non-determinism is a defect.

---

## Freeze Criteria

The release is frozen when:

- [ ] 0 compilation errors, ≤4 warnings (both with and without `Production/`)
- [ ] All 5 design invariants verified in writing
- [ ] `CConfigManager` loads, validates, and serves immutable configuration
- [ ] `CVersionManager` tracks platform version and module compatibility
- [ ] `CMigrationManager` registers and executes migration steps
- [ ] `CStartupValidator` validates all 4 startup phases
- [ ] `CEnvironmentValidator` checks terminal, account, symbols, data feed
- [ ] `CFaultManager` classifies faults into 3 severity levels
- [ ] `CRecoveryManager` executes recovery without modifying trading state
- [ ] `CHealthSupervisor` aggregates status across registered modules
- [ ] `CDiagnosticEngine` produces structured diagnostics
- [ ] `CLogExporter` formats and exports logs
- [ ] `CPerformanceProfiler` records and reports timing metrics
- [ ] `CDeploymentVerifier` produces actionable `DeploymentReport`
- [ ] `CProductionReport` formats all report types
- [ ] Removal of `Production/` directory verified to produce identical trading behavior
- [ ] `git tag v2.1-production-hardening` created and pushed

---

## Out of Scope

The following are explicitly excluded from Sprint 19:

1. **No trading logic changes.** No changes to `Structure/`, `Confluence/`, `Entry/`, `Trading/`, `Risk/`, `Portfolio/`, `Monitoring/`, or `Optimization/`.

2. **No new trading features.** No entries, exits, risk rules, portfolio rules, or signals.

3. **No machine learning.** No predictive models, classifiers, or training pipelines.

4. **No live trading integration.** Broker APIs, order routing, and execution infrastructure remain unchanged.

5. **No dashboard or UI.** Reports remain text/CSV/JSON files. Visualization is out of scope.

6. **No external monitoring integration.** Prometheus, Grafana, or similar exporters are reserved for a future sprint.

7. **No automated deployment pipeline.** CI/CD configuration is out of scope.
