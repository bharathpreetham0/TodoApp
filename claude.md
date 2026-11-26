# Data, API and operations

Every data question becomes a list of atoms (metric, period, measure), fetched by query and combined by each metric's time behaviour. This tab and the Agent and answers tab together form the low-level design.

## Request path

1. `understand` returns a `QueryPlan` (LLM).
2. `resolve` and `gate` return a frozen `ResolvedTask` or the questions to ask.
3. `registry.expand` turns each metric into base references, each with a balance point.
4. `plan_atoms` lists the exact rows needed and fails if any is missing.
5. `compile_facts` runs one query. FX translation applies per row, only if needed.
6. `reduce_atoms` aggregates time, then `evaluate` applies formulas.
7. The operation (value, trend, compare, breakdown, driver, rank) builds results and citations.
8. `compose` renders and verifies.

| Request type | LLM calls |
| --- | --- |
| Single value, exact metric | 1 (understand; templated answer) |
| Trend, compare, driver | 2 (understand, narrate) |
| Ambiguous or unconfigured metric | 1 more (select or propose) |
| Glossary definition | 1 (understand) |

RAG service calls are additional. Load the registry and data coverage index into memory per version.

## Resolution and gate

Each slot is filled in a fixed order: clarified answer, explicit mention, inherited value, approved default. An explicit mention that fails never falls back to a default.

```python
def resolve_slot(slot, sub, ctx, answers):
    if slot in answers:
        return Resolved(values=answers[slot], provenance="clarified")
    if mentions := ctx.mentions(sub, slot):
        matches = [ctx.match(slot, m) for m in mentions]
        if any(len(found) != 1 for found in matches):          # never fall back
            return SlotIssue(task_id=sub.id, slot=slot,
                             reason="ambiguous" if any(matches) else "unknown",
                             options=ctx.options(slot, sub, matches))
        return Resolved(values=tuple(f[0] for f in matches), provenance="explicit")
    if sub.inherits_previous and (previous := ctx.inherited(slot)):
        return Resolved(values=previous, provenance="inherited")
    if default := ctx.default(slot, sub):
        return Resolved(values=default, provenance="default")
    return SlotIssue(task_id=sub.id, slot=slot, reason="missing",
                     options=ctx.options(slot, sub, []))
```

The gate then checks the combination, in this order:

| Check | Failure result |
| --- | --- |
| User may see the entity, scenario and period | Refuse without listing restricted options |
| Metric is valid for the scope and period | `invalid` issue |
| Metric status is approved, or the formula is confirmed | `unconfirmed` issue |
| Entities and currency can be compared | Ask for currency or basis |
| Required atoms exist | `no_data` with the nearest available periods |

Only a task with no issues becomes a `ResolvedTask`.

## Data model

```sql
CREATE TABLE fact_financial (
  data_version   int           NOT NULL,
  scenario       text          NOT NULL,   -- actual | budget | forecast
  fx_basis       text          NOT NULL,   -- reported | constant
  currency       char(3)       NOT NULL,
  entity_id      text          NOT NULL REFERENCES dim_entity,
  metric_id      text          NOT NULL,
  period_id      text          NOT NULL REFERENCES dim_period,
  measure        text          NOT NULL
    CHECK (measure IN ('movement','opening','closing','reported')),
  amount         numeric(24,6) NOT NULL,
  unit           text          NOT NULL,
  source_file    text          NOT NULL,
  source_locator text          NOT NULL,   -- sheet/row or page
  load_id        uuid          NOT NULL,
  PRIMARY KEY (data_version, scenario, fx_basis, currency,
               entity_id, metric_id, period_id, measure)
);
```

| Table | Key columns |
| --- | --- |
| `dim_entity` | entity, parent, reporting currency, scope type |
| `dim_period` | period, grain (month, quarter, half, FY), fiscal year, start, end |
| `fx_rate` | rate set, from, to, period, average or closing rate |
| `data_release` | version, status, published time, approver |
| `period_status` | version, entity, period, open, closed, audited or restated |

Store group scopes such as Group ex-Optus as their own entity rows when Finance reports them.

## Time rules for P&L, balance sheet and cash flow

Behaviour belongs to each metric, not each statement. Cash flow contains both movements and opening and closing cash.

| Behaviour | Typical lines | Stored as |
| --- | --- | --- |
| `flow` | Revenue, expense, capex, cash movements | `movement` per month, not cumulative |
| `balance` | Assets, debt, equity, cash at start or end | `opening` and `closing` per month |
| `non_additive` | Reported figures that cannot be rebuilt | `reported` per exact period |
| `derived` | Margins, ratios, subtotals not stored | Not stored; formula in catalog |

| Request | Flow metric | Balance metric |
| --- | --- | --- |
| FY26 | April 2025 to March 2026 total | Closing at 31 March 2026 |
| H1 FY27 | April to September 2026 total | Closing at 30 September 2026 |
| YTD | April to latest closed month | Latest closed month-end |
| Opening FY26 | Not applicable | Opening of April 2025 |
| Average FY26 | Only if a metric defines it | (Opening + closing) / 2, if Finance agrees |
| Monthly trend | Monthly amounts | Month-end balances |
| FY26 vs FY25 | Difference of totals | Difference of closing balances |
| Movement in the year | The total itself | Closing minus opening |

- Show balances as "as at" a date, and flows as "for" a period.
- If the source gives year-to-date values, convert at load: month = this YTD minus prior YTD; April = April YTD.
- A Finance-reported period total takes precedence over the month sum. This covers year-end adjustments.
- With only annual or half-year data, load flows under that period, and opening and closing under its first and last month.
- A missing month means no total. Offer a clearly labelled shorter period instead.

```python
@dataclass(frozen=True)
class Atom:
    metric_id: str
    period_id: str      # "M2025-04", "H1FY26", "FY26"
    measure: Measure    # movement | opening | closing | reported

def plan_atoms(mid, behaviour, p: Period, point: Point, have: set[Atom]) -> list[Atom]:
    if behaviour == "flow":
        total = Atom(mid, p.id, "movement")
        need = [total] if total in have else [Atom(mid, m, "movement") for m in p.months]
    elif behaviour == "balance":
        opening = Atom(mid, p.months[0], "opening")
        closing = Atom(mid, p.months[-1], "closing")
        need = {"opening": [opening], "closing": [closing],
                "average": [opening, closing]}[point]
    else:               # non_additive: exact reported period only
        need = [Atom(mid, p.id, "reported")]
    missing = [a for a in need if a not in have]
    if missing:
        raise MissingData(missing)
    return need

def reduce_atoms(behaviour, point: Point, values: list[Decimal]) -> Decimal:
    if behaviour == "flow":
        return sum(values, Decimal(0))
    if behaviour == "balance" and point == "average":
        return sum(values, Decimal(0)) / 2
    (only,) = values    # fails loudly if more than one row
    return only
```

`have` is the coverage for one entity, scenario, currency, FX basis and data version.

### Ratios and FX

- A ratio mixing both, such as return on equity, declares `point: average` for equity. Part-year annualisation must be declared too, otherwise return no value.
- Aggregate numerator and denominator first, then divide.
- When converting, flows use each period's average rate. Balances use the closing rate at their date; opening uses the prior closing rate.
- Converted roll-forwards need a separate FX translation line, or they will not tie.

## Catalog and core interfaces

One Pydantic model validates every metric across all YAML files.

```python
class Ref(BaseModel):
    metric: str
    sign: Literal[1, -1] = 1
    point: Point | None = None          # overrides the requested balance point

class Formula(BaseModel):
    kind: Literal["sum", "ratio"]
    components: list[Ref] = []
    numerator: Ref | None = None
    denominator: Ref | None = None
    scale: Decimal = Decimal(1)         # 100 for percent

class MetricDef(BaseModel):
    id: str
    name: str
    synonyms: list[str] = []
    statement: Literal["pnl", "balance_sheet", "cash_flow", "kpi"]
    behaviour: Literal["flow", "balance", "non_additive", "derived"]
    default_point: Point = "closing"
    unit: Literal["amount", "percent", "multiple", "count"]
    formula: Formula | None = None      # required if derived; optional on stored subtotals
    overrides: dict[str, Formula] = {}  # by scope
    valid_scopes: list[str]
    status: Literal["draft", "approved", "deprecated"]
    effective_from: str
    effective_to: str | None = None
    owner: str
```

Keep statement layouts (line order and subtotals) in separate YAML, so "show the Optus balance sheet for FY26" runs as one query.

```python
def run_sql_task(t: ResolvedTask, rt: Runtime) -> TaskResult:
    leaves = rt.registry.expand(t)                 # (metric, scope, period, point)
    atoms = plan_all(leaves, rt.coverage)          # raises MissingData
    rows = rt.repo.fetch(compile_facts(t, atoms, rt.data_version))
    rows = translate(rows, t.currency, rt.fx)      # no-op for stored currency
    values = evaluate_all(t, leaves, rows, rt.registry)   # values + lineage
    return OPERATIONS[t.op](t, values)

def compile_facts(t, atoms: list[ScopedAtom], version: int) -> Select:
    f = fact_financial.c
    keys = sorted({(a.entity_id, a.metric_id, a.period_id, a.measure) for a in atoms})
    return select(fact_financial).where(
        f.data_version == version,
        f.scenario == t.scenario,
        f.fx_basis == t.fx_basis,
        f.currency == source_currency(t),
        tuple_(f.entity_id, f.metric_id, f.period_id, f.measure).in_(keys),
    )
```

`ScopedAtom` is an `Atom` plus its entity. `source_currency` returns the requested currency when stored, otherwise the entity's reporting currency. If entities need different source currencies, run one query per currency.

| Module | Owns | Tests |
| --- | --- | --- |
| `semantic/` | Load, validate, expand, search | Duplicates, cycles, overrides |
| `resolve/` | Slots, defaults, gate | Table of input and expected result |
| `sql/` | Coverage, compiler, repository | Compiled SQL snapshots |
| `analytics/` | Time, FX, formulas, operations | Signed figures, missing data, zero base |
| `graph/` | Nodes and edges only, no finance rules | Recorded LLM plans |

## RAG adapter

The graph talks to the managed RAG service through one interface, so filters and citation rules are enforced in one place.

```python
class DocQuery(BaseModel):
    question: str                  # approved template filled from resolved values
    entity_ids: list[str]
    periods: list[str]
    doc_types: list[str] = []
    access_groups: list[str]       # from the authenticated user
    top_k: int = 8

class Passage(BaseModel):
    document_id: str
    page: int | None
    text: str
    published: date | None

class RagResult(BaseModel):
    status: Literal["ok", "not_found", "unavailable"]
    answer: str | None = None      # if the service generates one
    passages: list[Passage] = []

class RagClient(Protocol):
    async def search(self, query: DocQuery) -> RagResult: ...
```

- An answer without passages is treated as `not_found`.
- Set a timeout. `unavailable` makes a hybrid response partial.

## API: request and response

One endpoint handles new questions and clarification replies. There is no streaming; a clarification is a normal HTTP 200 response.

| Endpoint | Purpose |
| --- | --- |
| `POST /v1/chat` | Question or clarification reply; returns the full response |
| `GET /v1/traces/{trace_id}` | Plan, resolution, SQL, versions (restricted) |
| `POST /v1/feedback` | Rating and correction |
| `DELETE /v1/threads/{thread_id}` | Remove a conversation, subject to retention rules |

```python
class ClarificationAnswer(BaseModel):
    clarification_id: str                # the LangGraph interrupt ID
    selections: dict[str, str]           # slot -> option ID

class ChatRequest(BaseModel):
    request_id: UUID                     # same value on client retries
    thread_id: UUID | None = None        # omit to start a conversation
    message: str | None = None
    answer: ClarificationAnswer | None = None   # exactly one of message or answer

class ChatResponse(AnswerPayload):
    request_id: UUID
    thread_id: UUID

@router.post("/v1/chat", response_model=ChatResponse)
async def chat(req: ChatRequest, user: User = Depends(authenticate),
               svc: Services = Depends(services)):
    thread_id = await svc.threads.get_or_create(req.thread_id, user.id)  # 404 if not owner
    async with svc.threads.lock(thread_id):                              # 409 if busy
        if saved := await svc.requests.find(thread_id, req.request_id):
            return saved
        config = {"configurable": {"thread_id": str(thread_id)}, "recursion_limit": 25}
        snap = await svc.graph.aget_state(config)
        pending = snap.interrupts[0] if snap.interrupts else None
        if req.answer:
            if not pending or pending.id != req.answer.clarification_id:
                raise HTTPException(409, "clarification is no longer open")
            payload = Command(resume={pending.id: req.answer.model_dump(mode="json")})
        elif pending:
            payload = Command(resume={pending.id: {"text": req.message}})
        else:
            payload = new_turn(req.message)
        async with asyncio.timeout(svc.settings.request_timeout_s):
            out = await svc.graph.ainvoke(
                payload, config, context=svc.context_for(user), durability="sync")
        response = to_response(out, thread_id, req.request_id)   # maps __interrupt__
        await svc.requests.save(thread_id, req.request_id, response)
        return response
```

- Typed text during a pause resumes the graph. `clarify` decides whether it answers the question or starts a new one.
- `context_for` rebuilds user access on every request, so it is never read from a checkpoint.
- The lock is a Postgres advisory lock held on its own connection pool.
- A crash between the run and the save can make a retried reply return 409. The client then asks again.

| HTTP | When |
| --- | --- |
| 200 | Answered, needs clarification, partial, no data, unsupported |
| 401 / 404 | Not signed in / thread not found or not owned |
| 409 | Thread busy or stale clarification |
| 422 | Invalid request or option |
| 503 / 504 | Dependency failure / time limit reached |

## Postgres checkpointing

Checkpoints hold conversation state only. Application tables hold ownership, responses and traces.

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    async with AsyncConnectionPool(
        settings.checkpoint_dsn, open=False,
        kwargs={"autocommit": True, "row_factory": dict_row, "prepare_threshold": 0},
    ) as pool:
        saver = AsyncPostgresSaver(pool)
        app.state.graph = build_graph().compile(checkpointer=saver)
        yield
```

```sql
CREATE TABLE chat_thread (
  thread_id uuid PRIMARY KEY, user_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_active_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE chat_request (
  thread_id uuid REFERENCES chat_thread ON DELETE CASCADE,
  request_id uuid, response jsonb NOT NULL, trace_id uuid NOT NULL,
  PRIMARY KEY (thread_id, request_id));
```

- Run `await saver.setup()` in the deployment migration step, not on each request.
- Use a separate schema and database role from the finance data.
- Store plain JSON in state (`model_dump(mode="json")`) and validate it inside nodes. Set `LANGGRAPH_STRICT_MSGPACK=true`.
- A retention job calls `adelete_thread` and removes the matching application rows.
- Encrypt at rest; checkpoints and saved responses contain financial figures.
- State records data, catalog and graph versions. If a paused version cannot be loaded on resume, restart the question and say so.

## Graph state and nodes

Per-question fields reset on every new turn; messages and the last resolved spec stay.

```python
def merge_results(old, new):
    return {} if new is None else {**(old or {}), **new}   # None resets

class AgentState(TypedDict, total=False):
    messages: Annotated[list, add_messages]
    last_spec: dict | None
    versions: dict                      # data, catalog, graph
    plan: dict | None
    resolved: list[dict]
    issues: list[dict]
    clarify_rounds: int
    results: Annotated[dict, merge_results]
    answer: dict | None

def new_turn(text: str) -> dict:
    return {"messages": [HumanMessage(text)], "versions": {}, "plan": None,
            "resolved": [], "issues": [], "clarify_rounds": 0,
            "results": None, "answer": None}
```

User context is passed with `context_schema=RequestContext` and is not stored in state. A changed question from `clarify` goes through the same per-question reset.

| Node | Writes | LLM | On failure |
| --- | --- | --- | --- |
| `load_context` | `versions` | No | 503 |
| `understand` | `plan` | Yes | One retry on invalid output, then 503 |
| `resolve` (includes metric selection and formula proposal) | `resolved`, `issues` | Only if ambiguous or unconfigured | Raise an issue to ask |
| `gate` | `issues` | No | Fail closed |
| `clarify` | `resolved` or new `plan` input, round count | No | Stop after two rounds |
| `plan_tasks` | Ready tasks | No | Mark unsupported |
| `sql_exec` | `results` | No | `no_data` with missing atoms; database errors give 503 |
| `rag_exec` | `results` | RAG service | Partial answer |
| `compose` | `answer`, `last_spec` | Narrative and unlisted definitions | Templated table |

A provisional formula is confirmed through `clarify`. Citation and prompt contracts are in the Agent and answers tab.

Each trace records node timings, prompt and model versions, tokens, resolved tasks, SQL, data version and verifier outcome. Keep message text and figures out of general application logs.

## Governance

No data release reaches users until it passes checks and has a named approver.

### Publish flow

1. Load into staging with source file, locator and load ID.
2. Build a candidate `data_version` and run the data checks.
3. Run benchmarks against the candidate.
4. Finance approves the release.
5. Switch the live version in one transaction; keep earlier versions for rollback.

Restatements create a new version and never overwrite. Answers show the version and mark restated periods. Pin one data and catalog version for the whole request, including a clarification pause. Recheck access on resume.

### Data checks

| Check | Rule | On failure |
| --- | --- | --- |
| Balance sheet | Assets = liabilities + equity | Block release |
| Continuity | Month opening = prior month closing | Block unless a restatement explains it |
| Roll-forward | Closing = opening + mapped movements, including FX | Block for mapped items |
| Cash tie-out | Cash flow closing cash = balance sheet cash, after declared reconciling items | Block release |
| Period totals | Reported total = month sum + declared adjustments | Block release |
| Hierarchy | Parent = signed children | Block release |
| Group | Group = entities + eliminations and adjustments | Block where all parts are loaded |
| Completeness | Expected entity, metric and period rows exist | Mark unavailable |

Finance sets the rounding tolerance for each check. Checks that need monthly data apply only where it is loaded.

### Ownership and change

| Asset | Owner | Change control |
| --- | --- | --- |
| Metric definitions, formulas, behaviour | Group Finance | Pull request, Finance review, benchmarks |
| Scope rules and FX policy | Group Finance | Same, with effective dates |
| Data releases | Data team; Finance approves | Publish flow |
| Prompts, model, graph | Engineering | Pull request and full benchmarks |
| Access rules | Data owner and security | Reviewed change and security tests |
| Provisional metric requests | Group Finance | Review queue: approve or reject |

Only `approved` metrics calculate without confirmation. Deprecated metrics point to their replacement.

## Benchmarks: location and execution

Keep benchmarks in the application repository but outside the deployed service. They run as a CI job or scheduled job, and exit non-zero when a gate fails.

```text
repo/
  app/                      service code
  tests/                    unit and integration tests (pytest)
  benchmarks/
    cases/
      understanding/  resolution/  clarification/  routing/
      sql/  analytics/  glossary/  retrieval/  rag/
      security/  e2e/
    verified/               references to Finance-signed values
    recordings/             recorded LLM outputs, no restricted data
    runner/                 cli.py, cases.py, targets.py, scorers.py, report.py
    gates.yaml
```

Keep restricted figures and board-paper content in access-controlled storage, not Git. Cases reference them by ID and version. Data checks run in the publish flow.

### Two run modes

| Mode | Calls | Used for |
| --- | --- | --- |
| Component | Resolver, compiler, analytics, one prompt | Fast, exact failures |
| API | `POST /v1/chat` and the trace endpoint | Multi-turn behaviour, access, end to end |

```python
class Case(BaseModel):
    id: str
    suite: str
    tags: list[str] = []
    user_role: str
    pins: Pins               # as_of, data and catalog version
    turns: list[Turn]        # ask or reply, plus expect

async def run_case(case: Case, api: ApiTarget) -> CaseResult:
    thread_id = clarification_id = None
    failures: list[str] = []
    for turn in case.turns:
        body = build_body(turn, thread_id, clarification_id)    # new request_id
        res = await api.chat(body, role=case.user_role, pins=case.pins)
        thread_id = res.thread_id
        clarification_id = res.clarification.id if res.clarification else None
        trace = await api.trace(res.trace_id)
        failures += score(turn.expect, res, trace)
        if failures:
            break
    return CaseResult(case_id=case.id, failures=failures)
```

Scorers compare structured fields and exact `Decimal` values within declared rounding, not answer wording. Pins and test roles are accepted only from the benchmark identity outside production.

### Gates

```yaml
resolution:    {min_pass_rate: 1.00}
sql:           {min_pass_rate: 1.00}
analytics:     {min_pass_rate: 1.00}
security:      {min_pass_rate: 1.00}
understanding: {min_pass_rate: 0.95}
routing:       {min_pass_rate: 0.98}
clarification: {min_precision: 0.90, critical_recall: 1.00}
retrieval:     {metric_top10: 0.99, document_hit: 0.90}
rag:           {min_pass_rate: 0.90}
glossary:      {min_pass_rate: 1.00}
e2e:           {max_wrong_figures: 0}
tagged:
  critical:    {min_pass_rate: 1.00}
```

### How to run

```bash
# pull request: no live model
python -m benchmarks.runner.cli --suite pr --llm recorded --target local
# prompt, model, catalog or graph change
python -m benchmarks.runner.cli --suite full --llm live --repeat 5 --target staging
# candidate data release
python -m benchmarks.runner.cli --suite data --data-version 42 --target staging
```

| When | Scheduler | Environment | If it fails |
| --- | --- | --- | --- |
| Pull request | CI | Local app, test Postgres | Block merge |
| Before release | CI | Staging | Block deployment |
| Data publish | Publish job | Staging with candidate version | Do not switch version |
| Daily 02:00 SGT | CI schedule or Kubernetes CronJob (`0 18 * * *` UTC) | Staging with production configuration | Alert the owner |
| After deployment | Deployment job | Production, read-only smoke set | Roll back |

A missing recording fails the case. With repeats, a critical case passes only if every run passes.

### Results

```sql
CREATE TABLE bench_run (
  run_id uuid PRIMARY KEY, started_at timestamptz, trigger text,
  git_sha text, model text, prompt_version text,
  catalog_version text, data_version int, passed boolean);
CREATE TABLE bench_result (
  run_id uuid REFERENCES bench_run, case_id text, attempt int,
  suite text, passed boolean, failures jsonb,
  latency_ms int, tokens int, trace_id uuid,
  PRIMARY KEY (run_id, case_id, attempt));
```

Each run produces a summary: gate status, new failures against the last passing run, flaky cases, latency and tokens. Benchmark threads use a separate checkpoint schema in test environments.


# Organisation Finance Chatbot: Low-Level Design

Nov 26, 2026 · @bharath preetham

## Design principle: the LLM interprets, code decides

The LLM turns a question into a typed request. Code resolves it, checks it, routes it, builds the SQL and calculates every number. The same resolved request on the same data version always gives the same answer.

| Step | Owner | Rule |
| --- | --- | --- |
| Understand and decompose | LLM | Structured output only; copies the user's words, never invents IDs |
| Resolve metric, scope, period, currency | Code + semantic layer | No unique match means ask |
| Completeness and routing | Code | Fixed policy table |
| SQL | Compiler (SQLAlchemy Core) | No LLM-written SQL, no free-form fallback |
| Formulas, growth, variance, FX | Code (Decimal) | Definitions come from the semantic layer |
| Narrative | LLM | References computed values by placeholder |
| Documents | Managed RAG service | Filtered by resolved scope, period and user access |

Start with one graph, not several autonomous agents. SQL and RAG are two executors behind a shared understanding layer.

## The LangGraph agent

&#91;embedded content: LangGraph agent flow · 7 steps, 1 clarification loop\]

Greetings, help requests and unsupported asks exit after step 2 with a templated reply.

```python
# AgentState and per-question reset: see the Data, API and operations tab
g = StateGraph(AgentState, context_schema=RequestContext)
for name, fn in NODES.items():
    g.add_node(name, fn)
g.add_edge(START, "load_context")
g.add_edge("load_context", "understand")
g.add_conditional_edges("understand", route_intent, ["resolve", "compose"])
g.add_edge("resolve", "gate")
g.add_conditional_edges("gate", route_gate, ["clarify", "plan_tasks", "compose"])
g.add_conditional_edges("clarify", route_reply, ["resolve", "understand", "compose"])
g.add_conditional_edges("plan_tasks", dispatch_ready, ["sql_exec", "rag_exec"])  # Send()
g.add_edge("sql_exec", "join")
g.add_edge("rag_exec", "join")
g.add_conditional_edges("join", next_wave, ["sql_exec", "rag_exec", "compose"])
g.add_edge("compose", END)
graph = g.compile(checkpointer=postgres_checkpointer)
```

Clear `plan`, `resolved`, `issues`, `results`&#32;

and `clarify_rounds` at the start of each new question. Keep `messages` and `last_spec`.

## Understanding and resolution

Use one structured LLM call for rewrite, intent, decomposition and extraction. It returns the user's words as mentions; resolvers convert them to canonical IDs.

### Context to load before routing

| Context | Why it matters |
| --- | --- |
| Today's date and fiscal calendar | Resolves "this year", "last half", YTD |
| Latest loaded period per entity and scenario | Stops queries on data you do not have |
| Top metric candidates (synonym + embedding search) | Grounds extraction without sending the whole catalog |
| Scope hierarchy and aliases | Separates Group, Group ex-Optus, Optus |
| Document index facets (type, entity, period) | Shows what RAG can answer |
| Last resolved spec and recent turns | Handles "and for Optus?" |
| User entitlements | Limits entities, scenarios and board papers |
| Glossary and a few reviewed examples | Covers house terms; keep these apart from test cases |

### Contracts

```python
class Mentions(BaseModel):
    metrics: list[str] = []
    scopes: list[str] = []
    periods: list[str] = []
    currency: str | None = None
    basis: list[str] = []      # actual, budget, forecast, constant currency, underlying
    breakdown_by: str | None = None

class SubTask(BaseModel):
    id: str
    question: str              # standalone rewrite
    op: Literal["value","trend","compare","breakdown","driver","rank","narrative","define"]
    needs_explanation: bool = False
    depends_on: list[str] = []
    mentions: Mentions
    inherits_previous: bool = False

class QueryPlan(BaseModel):
    intent: Literal["data","document","hybrid","knowledge","chitchat","unsupported"]
    subtasks: list[SubTask] = Field(max_length=5)

class Period(BaseModel):
    id: str                    # "FY26", "H1FY27"
    months: tuple[str, ...]
    kind: Literal["month","quarter","half","fy","ytd"]

class SlotIssue(BaseModel):
    task_id: str
    slot: str
    reason: Literal["missing","ambiguous","unknown","invalid","no_data","unconfirmed"]
    options: list[Option] = [] # id and label, filtered by access

class ResolvedTask(BaseModel):
    model_config = ConfigDict(frozen=True)
    task_id: str
    op: str
    metric_ids: tuple[str, ...]
    scope_ids: tuple[str, ...]
    periods: tuple[Period, ...]
    point: Literal["opening","closing","average"] | None = None
    currency: Literal["SGD","AUD","USD"]
    scenario: Literal["actual","budget","forecast"]
    fx_basis: Literal["reported","constant"]
    breakdown_by: str | None
    provenance: dict[str, Literal["explicit","inherited","default","clarified"]]
```

### Slot resolution rules

- **Metric:** match exact name, then approved synonym. A search-only match is a suggestion to confirm. Never use the model's self-reported confidence.
- **Scope:** use an explicit enum: `GROUP` (includes Optus), `GROUP_EX_OPTUS`, `OPTUS`, `SG_ORG`, `NCS`, `DIGITAL_INFRACO`, plus associates. Define each composite with Finance. Do not derive ex-Optus by subtraction unless Finance approves it, including eliminations.
- **Period:** the organisation's financial year runs April to March, so FY26 is April 2025 to March 2026. The parser is code and returns a `Period`.
- **"This year":** today it means FY27, but your annual data covers FY24 to FY26. Ask: FY27 year to date (if loaded) or FY26, the last full year.
- **Currency:** separate display currency from FX basis. Prefer stored reported values. Any conversion uses a versioned rate table, with rate rules in the Data, API and operations tab.
- **Basis:** actual vs budget vs forecast, reported vs underlying, and original vs restated are separate dimensions.

Newer results may be in scraped documents before they are loaded into the database. If so, say which source answered.

## Clarification criteria

Execute only when every required slot has exactly one valid value from an explicit mention, inheritance, an approved default or the user's answer.

| Slot | Required for | Proposed default | Ask when |
| --- | --- | --- | --- |
| Metric | All data tasks | None | No match, several matches, or a vague term ("profit", "performance") |
| Scope | All data tasks | None | Missing, or "Group" could mean with or without Optus |
| Period | All data tasks | None; trend: last 3 full FYs | Missing or relative ("this year") |
| Comparison base | Compare, driver | Prior year, same period type | The phrase suggests budget or another entity |
| Currency | All data tasks | SGD for Group; Optus has no default | Optus without a currency, or mixed-entity comparison |
| Scenario | All data tasks | Actual | Budget and forecast versions both could apply |
| Breakdown dimension | Breakdown, driver | The metric's primary tree | Several trees exist |

Confirm these defaults with Finance. Show every default and inherited value above the answer, for example: "Group incl. Optus · FY26 vs FY25 · SGD · Actual".

### Behaviour

- Ask one message covering all open slots, with options generated from the catalog.
- Offer only options that have data and that the user may see.
- Allow two rounds, then state what is still missing and stop.
- If the reply is a new question, drop the pending one and start again.
- Follow-ups replace only the slots the user mentions. If an inherited value is invalid for the new request, ask.
- Check access before offering options, so a clarification never reveals restricted entities or documents.

```python
def clarify(state: AgentState):
    prompt = build_question(state["issues"])   # pure and repeatable
    reply = interrupt(prompt.model_dump())     # node re-runs from the top on resume
    return apply_reply(state, prompt, reply)   # option IDs, free text or new question
```

[LangGraph interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts) need a durable checkpointer and the same `thread_id` on resume. Keep side effects out of the code before `interrupt()`. The clarify node routes to `resolve`, to `understand` for a changed question, or to `compose` at the round limit.

## Semantic layer and SQL compiler

One parameterised query fetches the base facts; pure Python functions do all the analysis. This keeps the SQL surface small enough to test completely.

### Metric contract

Map your existing semantic layer to the `MetricDef` model in the Data, API and operations tab. The formulas below are placeholders, not your organisation's definitions. A stored subtotal may also carry a formula, used for breakdowns and data checks.

```yaml
- id: operating_profit
  name: Operating profit
  synonyms: [operating income]
  statement: pnl
  behaviour: flow          # stored; formula drives breakdown and checks
  unit: amount
  formula:
    kind: sum
    components:
      - {metric: operating_revenue, sign: 1}
      - {metric: operating_expense, sign: -1}
  valid_scopes: [GROUP, GROUP_EX_OPTUS, OPTUS]
  status: approved
  effective_from: FY24
  owner: group-finance
- id: operating_margin
  name: Operating margin
  statement: pnl
  behaviour: derived       # not stored; recompute from parts
  unit: percent
  formula:
    kind: ratio
    numerator: {metric: operating_profit}
    denominator: {metric: operating_revenue}
    scale: 100
  valid_scopes: [GROUP, GROUP_EX_OPTUS, OPTUS]
  status: approved
  effective_from: FY24
  owner: group-finance
```

Validate the catalog in CI: unique synonyms (or declared ambiguities), no formula cycles, every base metric mapped to data.

### Formula evaluation

The fact table, time rules and query compiler are in the Data, API and operations tab. Evaluation walks the formula and returns each value with its inputs, which become the citation tree.

```python
def evaluate(ref: Ref, key: Key, facts: Facts, registry: Registry) -> Node:
    metric = registry[ref.metric]
    if metric.behaviour != "derived":
        return facts.leaf(metric, key, ref.point or key.point)   # value + source, or MissingData
    formula = metric.overrides.get(key.scope, metric.formula)
    if formula.kind == "ratio":
        num = evaluate(formula.numerator, key, facts, registry)
        den = evaluate(formula.denominator, key, facts, registry)
        ok = num.value is not None and bool(den.value)
        value = num.value / den.value * formula.scale if ok else None   # None shows as n/m
        return Node(metric_id=metric.id, value=value, inputs=[num, den])
    inputs = [evaluate(c, key, facts, registry) for c in formula.components]
    value = None
    if all(n.value is not None for n in inputs):
        value = sum((c.sign * n.value for c, n in zip(formula.components, inputs)), Decimal(0))
    return Node(metric_id=metric.id, value=value, inputs=inputs)
```

Where Finance reports a parent total, treat it as the record and reconcile the computed children against it.

### Analysis operations

| Operation | Computation | Guard |
| --- | --- | --- |
| Value | Metric at one scope and period | Show unit and scale |
| Trend | Ordered series of like periods | Flag gaps, restatements, definition changes |
| Compare | Absolute and % change | % is n/m for zero or negative base; margins in points |
| Breakdown | Children from the metric tree | Show any unexplained residual |
| Driver | Sign × change in each child, ranked | Contributions plus residual equal total change |
| Rank | Sort scopes on a common currency and basis | Exclude overlapping scopes |

Run on a read-only role with row-level security, a statement timeout and a row limit. Log the resolved task, compiled SQL, parameters, data version and catalog version.

## Routing, RAG and hybrid

Route each subtask after resolution, based on what the catalog and indexes can answer.

| Condition | Route |
| --- | --- |
| Metric in catalog and data covers the request | SQL |
| Narrative: strategy, commentary, board discussion, announcements | RAG |
| "Why", "what drove", or `needs_explanation` | SQL first, then RAG |
| Figure not in the database but documents may hold it | RAG, labelled "from documents" |
| Catalog metric, but the period is not loaded | Say so; offer a document search |
| Neither can answer | Say unsupported and log it |

### Hybrid execution

Example: "Which opco's EBIT fell most in FY26, and why?"

1. `t1` (SQL): rank opcos by EBIT change, FY26 vs FY25, after currency and basis are confirmed.
2. `t2` (RAG, depends on `t1`): fill an approved query template with the resulting opco, metric and period.
3. Compose: figures and driver bridge from SQL, explanations from cited passages.

Independent subtasks run in parallel with `Send`; dependent ones run in the next wave. If one branch fails, return the other and say what is missing.

### Managed RAG contract

- Tag documents at ingestion: entity, fiscal period, document type, publish date, version, access list, source URL and file hash.
- Send those as filters. Access filtering must happen inside retrieval, not after generation. Confirm your managed service supports this.
- Require passages with document ID and page. No supporting passage means "not found".
- The database is the record for figures. If a document figure differs, show both with period and basis, and flag it.
- A driver explanation must come from a document. A SQL bridge shows what moved, not why management says it moved.
- Treat scraped and uploaded text as data, never instructions. Allow only approved source domains and deduplicate versions.

## Answer composition and security

The model writes sentences with placeholders such as `{v1}`, and code inserts formatted values. A verifier blocks the narrative if it breaks a rule, then falls back to a table with a templated summary.

**Verifier rules**

- No SQL figure typed by the model; every placeholder exists.
- Direction words ("rose", "fell") come from code, as placeholders too.
- Document figures appear in the cited passage.
- Causal claims carry a citation.
- Requested subtasks are all answered or explicitly marked missing.

```python
class AnswerPayload(BaseModel):
    status: Literal["answered","needs_clarification","partial","no_data","unsupported"]
    interpretation: list[Chip]        # slot, value, provenance
    narrative: str
    tables: list[Table]
    chart: ChartSpec | None           # trend: line; compare: bar; driver: waterfall
    formulas: list[FormulaTrace]
    citations: list[FigureCitation | DocumentCitation]
    clarification: Clarification | None
    data_version: str
    trace_id: str
```

**Security**

- Board papers and unreleased results are likely price-sensitive. Enforce entitlements in SQL, retrieval, caches, logs and traces.
- Take identity from the authenticated request, never from chat text.
- Check that each `thread_id` belongs to the caller.
- Key any cache on resolved task, data version, catalog version and entitlements.
- Confirm where model calls and traces are processed and retained.

## Benchmarks

Score each layer separately, so a failure points to one component. The targets below are proposed starting gates.

| Layer | What is checked | Gate |
| --- | --- | --- |
| Understanding | Intent, subtasks, dependencies, mentions | At least 95% exact |
| Resolution | Canonical IDs from fixed mentions | 100% |
| Clarification | Asks when needed; does not ask otherwise | Recall 100% on critical cases; precision at least 90% |
| Routing | SQL, RAG, hybrid, unsupported | At least 98% |
| SQL and calculation | Compiled SQL snapshot and exact values | 100% |
| RAG | Expected document retrieved, citation supports claim | At least 90% |
| End to end | Status, interpretation, values, citations | No wrong figure in any run |
| Security | Restricted data and injected instructions | 100% |
| Data quality | Balance sheet balances, children match parents, halves sum to years | 100% within agreed rounding |

```yaml
- id: drv-007
  tags: [driver, optus, critical]
  suite: e2e
  pins: {as_of: 2026-11-26, data_version: 42, catalog_version: v1}
  user_role: group_finance
  turns:
    - ask: "Why did Optus operating profit change this year?"
      expect: {status: needs_clarification, slots: [period, currency]}
    - reply: {period: FY26, currency: AUD}
      expect:
        route: hybrid
        resolved: {metric: operating_profit, scope: OPTUS, compare_to: FY25}
        values_from: verified/optus_op_fy26_bridge.csv
        citation_docs: [optus_fy26_results]
```

Benchmark location, run commands, gates and schedule are in the Data, API and operations tab.

- Pin `as_of`, data version, catalog version, prompt version and model. Without this, "this year" tests drift.
- Expected values come from Finance-signed figures, not from the system's own output.
- Run deterministic tests with recorded LLM plans; run LLM tests live.
- Report repeat consistency, latency and cost beside accuracy. Block release when a gate fails.
- Start with about 150 cases covering every operation, scope and ambiguity. Add every production miss.

Results are stored by run and version for trend comparison.

## Derived metrics and definition questions

One semantic catalog serves both calculations and definitions. The LLM identifies the term; code supplies the formula and the value.

| User asks | Task | Needs scope and period | Answered from |
| --- | --- | --- | --- |
| "What is the full form of P&L?" | `define` | No | Glossary |
| "What is EBITDA?" | `define` | No | Glossary |
| "How is operating margin calculated?" | `define` | No | Metric catalog formula |
| "What is Optus operating margin for FY26 in AUD?" | `value` | Yes | Formula applied to stored components |
| "What is operating margin?" | `define` | No | Definition, then offer to calculate |
| "What is EBITDA and how did it move?" | `define` + `compare` | Only for `compare` | Glossary and SQL |

### Metrics that are not stored

Declare each one in the catalog as a `ratio` or `sum` over stored metrics, as in the operating margin example above. `evaluate` computes it, so no stored column is needed.

```text
operating margin % = operating profit / operating revenue × 100
```

- Finance approves the formula, including which profit measure it uses and any scope-specific variant.
- Calculate from components at the requested scope and period. Never average margins across halves or entities.
- Show the formula and both inputs with the result.
- If a component is missing, name it and return no value.
- If no approved formula exists, follow the tiers under "Unconfigured metrics" below.

### Glossary

```yaml
- term: EBITDA
  expansion: Earnings before interest, tax, depreciation and amortisation
  definition: Operating earnings before financing, tax and non-cash asset charges.
  company_note: null        # Finance adds organisation-specific inclusions
  synonyms: []
  metric_id: ebitda         # null for non-metrics such as P&L
  status: approved
  source: group-finance
- term: P&L
  expansion: Profit and loss statement
  definition: Statement of revenue, costs and profit over a period.
  metric_id: null
  status: approved
```

Look up answers in this order, and label the source:

1. Approved glossary or metric catalog.
2. Company documents through RAG, with citation.
3. LLM general knowledge, marked "general definition, not organisation-specific", with no company figures or claims.

If a term has several meanings in your business, ask which one. Definition tasks skip the slot requirements at the gate and do not overwrite `last_spec`'s scope or period. They do record the metric, so "what is it for Optus in FY26?" works next.

In the graph, a `define` task found in the glossary or catalog goes from the gate straight to compose. One that is not found goes through plan and route to the RAG executor.

### Benchmark cases to add

- Definition questions never trigger a scope or period clarification.
- Acronym expansions match the glossary exactly.
- Derived values match Finance-signed figures.
- Unapproved metrics are calculated only after user confirmation, with a provisional label.

## Unconfigured metrics

Always explain a recognised financial term. Calculate an unconfigured metric only from approved components, after the user confirms the formula.

| Tier | Condition | Bot response |
| --- | --- | --- |
| Approved | Metric is in the catalog | Calculate |
| Provisional | Standard formula; every input maps to one approved metric | Show formula, ask to confirm, calculate, label "Provisional" |
| Definition only | An input is missing, ambiguous or needs a convention | Explain it, name the gap, offer related metrics |
| Unknown | Term not recognised or company-specific | Check documents, otherwise ask what the user means |

Example: "I can calculate operating margin as operating profit ÷ operating revenue. It is not yet a Finance-approved definition. Proceed?"

```python
class ProposedMetric(BaseModel):
    name: str
    kind: Literal["ratio", "sum"]
    numerator: str | None = None          # must be a candidate metric ID
    denominator: str | None = None
    components: list[Ref] = []
    unit: Literal["percent", "multiple", "amount"]
```

- The LLM proposes this object, never SQL or a number. Code validates IDs, units, time behaviour and scope.
- Mixed balance and flow metrics (such as return on equity) need an averaging convention, so they stay definition only.
- The confirmation applies to that thread only. Provisional results are never cached as approved.
- Finance can switch the tier off by role or metric family. Frequent requests go to a review queue.

## Citations

Every number carries lineage built by code; the LLM never writes a citation.

| Figure type | Citation shows |
| --- | --- |
| Stored metric | Metric, entity, period, scenario, currency, source file and sheet or page, data version |
| Calculated metric | Formula, catalog version, status, then a citation for each input |
| Aggregate (periods or entities) | Aggregation rule, member list, each member's source, any eliminations |
| Converted value | Source amount, rate, rate type and rate table version |
| Document statement | Document, page, passage, publish date |

```python
class FigureCitation(BaseModel):
    ref: str                       # "v1"
    value: Decimal
    metric_id: str
    formula: str | None
    status: Literal["approved", "provisional"]
    context: dict[str, str]        # entity, period, scenario, currency
    inputs: list["FigureCitation"] = []
    source: SourceRef | None       # leaf: file, sheet/page, row
    data_version: str
    query_id: str
```

- Add source file, sheet or page, row reference and load ID to the fact view. Without these, lineage stops at the table.
- Extend the compiler's `select` to return them, and `evaluate` to return this tree with each value.
- Show one marker per figure; expand it to the tree. Large aggregates show top members and a downloadable list.
- Show SQL only to authorised users through the trace endpoint.
- Link a published page only when value, entity, period, currency and basis all match.

## Prompt strategy for a large semantic layer

Never send the YAML files to the model. Compile them into a registry, then give each prompt only the few entries it needs.

1. **Compile at build time.** Load all 7 to 8 files into validated Pydantic objects. Fail on duplicate IDs, broken references and formula cycles.
2. **Remove repetition.** Keep one base definition per metric, with overrides per scope such as Group ex-Optus.
3. **Index a short card per metric.** Index name, synonyms and description. Formulas and mappings stay in code.
4. **Retrieve per mention.** Exact and synonym match first, then keyword plus embedding search, filtered by statement and scope. Keep the top 10.
5. **Select only if needed.** A unique exact match skips the LLM. Otherwise the model picks candidate IDs or `none`, and a non-exact pick is confirmed by the user.

```yaml
# registry: base plus overrides
id: operating_profit
formula: {kind: sum, components: [{metric: operating_revenue}, {metric: operating_expense, sign: -1}]}
overrides:
  GROUP_EX_OPTUS:
    kind: sum
    components: [{metric: revenue_ex_optus}, {metric: expense_ex_optus, sign: -1}]
---
# card sent to the model
id: operating_profit
name: Operating profit
statement: pnl
means: Profit from operations as Finance defines it
not_to_be_confused_with: [ebitda, net_profit]
```

### Prompts

| Prompt | Runs | Receives | Returns |
| --- | --- | --- | --- |
| Understand | Every turn | Question, recent spec, calendar, scope list | `QueryPlan` |
| Select metric | Ambiguous mention | Mention, question, up to 10 cards | IDs or `none` |
| Propose formula | Unconfigured metric | Term, candidate base cards | `ProposedMetric` or reason |
| Define | Term not in glossary | Term, passages if any | Labelled definition |
| Narrate | After execution | Placeholders, facts, passages | Text with placeholders |

```text
SYSTEM (select metric)
You match a finance term to catalog entries.
- Choose only from the candidate IDs.
- Return "none" if no entry means the same thing.
- Return every ID that fits if the term is ambiguous.
- Related is not the same: EBITDA is not operating profit.

USER
Question: {question}
Term: {mention}
Scope: {scope_or_unknown}
Candidates: {cards}
```

- Use structured output, with allowed IDs generated per request.
- Put fixed instructions first and variable content last, so prompt caching can apply.
- Keep business rules in code and the catalog, not in prompt text.
- Add a few examples per prompt, covering ambiguity and `none`.
- Version prompts with the catalog. Benchmark retrieval separately: target the right metric in the top 10 at least 99% of the time.

## Code layout and delivery plan

Build the deterministic core first; it can be fully tested before any prompt exists.

The API is request and response only. Its endpoints and contracts are in the Data, API and operations tab.

```text
app/
  api/          FastAPI routes, auth
  graph/        state, nodes, edges
  contracts/    Pydantic models
  semantic/     catalog YAML, loader, validators
  resolve/      metric, scope, period, currency, policy
  sql/          tables, compiler, repository
  analytics/    formulas, compare, bridge, FX
  rag/          managed service adapter
  compose/      templates, verifier
  llm/          client, prompts (versioned)
benchmarks/     cases, verified values, runner
```

| Phase | Deliver | Exit test |
| --- | --- | --- |
| 1 | Validated catalog with behaviour tagged, one entity-year loaded and checked, time rules, compiler, formulas | 20 key metrics match signed figures |
| 2 | Understand, resolve, gate, clarify for single values | Understanding and clarification gates pass |
| 3 | Trend, compare, breakdown, driver, follow-ups | All operations pass on verified cases |
| 4 | RAG adapter, hybrid, verifier | Citation and security gates pass |
| 5 | Pilot with Finance users | No wrong figure across agreed pilot set |

### Questions for Finance and your team

- [ ] How is "Group excluding Optus" defined, including eliminations?
- [ ] Is FY27 half-year data being loaded, and what should "this year" mean?
- [ ] Which currencies are stored, and which FX rates are approved?
- [ ] Which defaults in the clarification table are acceptable?
- [ ] How are restatements and definition changes versioned across FY24 to FY26?
- [ ] Are budget and forecast in scope, and who may see them?
- [ ] Does the managed RAG service support access filters and page citations?

Also confirm whether monthly data exists for FY24 to FY26, whether sources are monthly or year-to-date, and the average-balance convention.
