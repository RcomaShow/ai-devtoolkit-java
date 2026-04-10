---
name: quarkus-observability
description: 'Structured logging, Micrometer metrics, and OpenTelemetry tracing patterns for Quarkus 3.x microservices. Reference when adding observability to any service layer.'
argument-hint: "Observability need — e.g. 'add metrics to service', 'structured logging', 'trace propagation'"
user-invocable: false
---

# Quarkus 3.x Observability — Logging · Metrics · Tracing

> Three pillars: **logs** answer "what happened", **metrics** answer "how often / how fast", **traces** answer "where did it happen across services".

---

## Context

All Quarkus 3.x microservices must ship with structured logs, Micrometer counters/timers, and OpenTelemetry traces from day one. Observability is not a post-launch concern.

---

## Key Concepts

| Term | Meaning |
|------|---------|
| **MDC** | Mapped Diagnostic Context — thread-local key-value pairs added to every log line |
| **Correlation ID** | A UUID generated at request entry, propagated through MDC and HTTP headers to link log lines across services |
| **Span** | A single timed operation within a trace (e.g. one service call, one DB query) |
| **Trace** | A tree of spans representing an end-to-end request across all services |
| **Meter** | A named measurement instrument — Counter, Timer, Gauge, DistributionSummary |
| **Micrometer** | Vendor-neutral metrics façade — exports to Prometheus, Datadog, etc. |
| **OpenTelemetry** | Vendor-neutral tracing/metrics standard — exports to Jaeger, Zipkin, OTLP |

---

## Dependencies

```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-opentelemetry</artifactId>        <!-- tracing + metrics OTLP -->
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-micrometer-registry-prometheus</artifactId>  <!-- metrics /q/metrics -->
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-health</artifactId>      <!-- health probes /q/health -->
</dependency>
```

---

## Patterns

### 1 — Structured Logging

**Rule**: Log at the correct level. Never log PII, passwords, or full request/response bodies.

```java
import org.jboss.logging.Logger;        // Quarkus preferred over SLF4J directly

@ApplicationScoped
public class {Entity}Service {

    private static final Logger LOG = Logger.getLogger({Entity}Service.class);

    public {Entity}Dto create(Create{Entity}Request request) {
        LOG.debugf("Creating {entity}: code=%s", request.code());   // debug: input params (no PII)

        var domain = mapper.toDomain(request);
        var saved  = {entity}Repository.save(domain);

        LOG.infof("{entity} created: id=%d", saved.id().value());    // info: business event
        return mapper.toDto(saved);
    }

    public void delete({Entity}Id id) {
        try {
            {entity}Repository.deleteById(id);
            LOG.infof("{entity} deleted: id=%d", id.value());
        } catch (EntityNotFoundException e) {
            LOG.warnf("Delete skipped — {entity} not found: id=%d", id.value());  // warn: expected edge case
        } catch (Exception e) {
            LOG.errorf(e, "Unexpected error deleting {entity}: id=%d", id.value()); // error: unexpected
            throw e;
        }
    }
}
```

**Log Level Rules:**

| Level | When to use | Example |
|-------|------------|---------|
| `DEBUG` | Input params, internal state, branches taken | `"Checking overlap: from=%s to=%s"` |
| `INFO` | Business events, state transitions | `"Order submitted: id=%d"` |
| `WARN` | Expected edge cases, degraded behavior | `"External service slow, using cached value"` |
| `ERROR` | Unexpected exceptions, data inconsistencies | `"Failed to persist entity after 3 retries"` |

**Never log:**
- Passwords, tokens, API keys (even partially)
- Full names, national IDs, dates of birth (GDPR)
- Full request/response bodies (contain any of the above)
- Stack traces at INFO level — use ERROR

### 2 — Correlation ID (MDC Propagation)

```java
import io.opentelemetry.api.trace.Span;
import org.jboss.logging.MDC;

@Provider
@Priority(1)
public class CorrelationIdFilter implements ContainerRequestFilter {

    @Override
    public void filter(ContainerRequestContext requestContext) {
        // Use incoming header if present (inter-service call) or generate new
        var correlationId = Optional
            .ofNullable(requestContext.getHeaderString("X-Correlation-Id"))
            .orElse(UUID.randomUUID().toString());

        MDC.put("correlationId", correlationId);
        MDC.put("traceId", Span.current().getSpanContext().getTraceId());
        requestContext.setProperty("correlationId", correlationId);
    }
}

// application.properties — include MDC in log format
quarkus.log.console.format=%d{HH:mm:ss} %-5p [%c{2.}] [%X{traceId}] [%X{correlationId}] %s%e%n
```

### 3 — Micrometer Metrics

```java
import io.micrometer.core.annotation.Counted;
import io.micrometer.core.annotation.Timed;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Timer;

@ApplicationScoped
public class {Entity}Service {

    private final MeterRegistry registry;
    private final Counter       failedCreations;
    private final Timer         createTimer;

    public {Entity}Service(MeterRegistry registry, ...) {
        this.registry = registry;

        // Named counters — use dots, not underscores
        this.failedCreations = Counter.builder("{domain}.{entity}.creation.failed")
            .description("Number of failed {entity} creation attempts")
            .tag("service", "{entity}-service")
            .register(registry);

        this.createTimer = Timer.builder("{domain}.{entity}.create.duration")
            .description("Time to create a {entity}")
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(registry);
    }

    // Annotation-based (simple cases)
    @Timed(value = "{domain}.{entity}.list.duration", histogram = true)
    @Counted(value = "{domain}.{entity}.list.calls")
    public List<{Entity}Dto> list() {
        return {entity}Repository.findAll().stream().map(mapper::toDto).toList();
    }

    // Programmatic (complex cases with tags / conditional recording)
    public {Entity}Dto create(Create{Entity}Request request) {
        return createTimer.record(() -> {
            try {
                var result = doCreate(request);
                registry.counter("{domain}.{entity}.creation.success").increment();
                return result;
            } catch (DomainValidationException e) {
                failedCreations.increment();
                throw e;
            }
        });
    }

    // Gauge — current state (not a rate)
    public void registerActiveEntityGauge() {
        Gauge.builder("{domain}.{entity}.active.count", {entity}Repository, repo -> repo.countActive())
            .description("Number of active {entities}")
            .register(registry);
    }
}
```

**Metric Naming Rules:**
- Format: `{domain}.{entity}.{operation}.{unit}` (dots, not underscores)
- Units: `.duration` (Timer), `.count` (Counter), `.size` (Gauge for sizes), `.errors`
- Tags: `service`, `environment`, `status` (use sparingly — each tag multiplies cardinality)

### 4 — OpenTelemetry Tracing

```java
import io.opentelemetry.instrumentation.annotations.WithSpan;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.Span;

@ApplicationScoped
public class {Entity}Service {

    @Inject Tracer tracer;

    // Annotation-based — creates child span automatically
    @WithSpan("{entity}.create")
    public {Entity}Dto create(@SpanAttribute("request.code") String code,
                               Create{Entity}Request request) {
        // ...
    }

    // Programmatic — for conditional or dynamic span names
    public List<{Entity}Dto> processBatch(List<Long> ids) {
        var span = tracer.spanBuilder("{entity}.batch-process")
            .setAttribute("batch.size", ids.size())
            .startSpan();

        try (var scope = span.makeCurrent()) {
            var results = ids.stream().map(this::process).toList();
            span.setAttribute("batch.processed", results.size());
            return results;
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(io.opentelemetry.api.trace.StatusCode.ERROR, e.getMessage());
            throw e;
        } finally {
            span.end();
        }
    }
}
```

**Span Attribute Rules:**
- Add attributes that help debug failures: entity IDs, request codes, counts
- Never add PII: names, emails, national IDs
- Keep attribute count under 10 per span

### 5 — SmallRye Health Checks

```java
// Liveness — is the process running correctly?
@Liveness
@ApplicationScoped
public class ApplicationLivenessCheck implements HealthCheck {

    @Override
    public HealthCheckResponse call() {
        return HealthCheckResponse.up("application-live");
    }
}

// Readiness — is the service ready to accept traffic?
@Readiness
@ApplicationScoped
public class {Service}ReadinessCheck implements HealthCheck {

    private final {External}Client client;

    @Override
    public HealthCheckResponse call() {
        try {
            var latencyMs = measurePing(() -> client.ping());
            return HealthCheckResponse.named("{service}-ready")
                .up()
                .withData("latency_ms", latencyMs)
                .build();
        } catch (Exception e) {
            return HealthCheckResponse.named("{service}-ready")
                .down()
                .withData("error", e.getMessage())
                .build();
        }
    }

    private long measurePing(Runnable action) {
        var start = System.currentTimeMillis();
        action.run();
        return System.currentTimeMillis() - start;
    }
}

// Startup — one-time check that dependencies are available at boot
@Startup
@ApplicationScoped
public class DatabaseStartupCheck implements HealthCheck {

    @Inject DataSource dataSource;

    @Override
    public HealthCheckResponse call() {
        try (var conn = dataSource.getConnection();
             var stmt = conn.createStatement()) {
            stmt.execute("SELECT 1 FROM DUAL");   // Oracle: FROM DUAL; MSSQL/PG: omit FROM
            return HealthCheckResponse.up("database-startup");
        } catch (SQLException e) {
            return HealthCheckResponse.down("database-startup");
        }
    }
}
```

---

## Configuration

```properties
# application.properties

# ── Logging ────────────────────────────────────────────────────────────────
quarkus.log.level=INFO
quarkus.log.category."{com.company.{domain}}".level=DEBUG   # verbose for own code
quarkus.log.console.json=true                               # structured JSON in prod
quarkus.log.console.format=%d{HH:mm:ss} %-5p [%c{2.}] [%X{traceId}] [%X{correlationId}] %s%e%n

# ── Micrometer (Prometheus) ─────────────────────────────────────────────
quarkus.micrometer.enabled=true
quarkus.micrometer.registry-enabled-default=true
quarkus.micrometer.export.prometheus.enabled=true
quarkus.micrometer.export.prometheus.path=/q/metrics

# ── OpenTelemetry ───────────────────────────────────────────────────────
quarkus.otel.enabled=true
quarkus.otel.exporter.otlp.endpoint=http://otel-collector:4317
quarkus.otel.service.name={service-name}
quarkus.otel.traces.sampler=traceidratio
quarkus.otel.traces.sampler.arg=0.1   # 10% sampling in prod

# ── Health ──────────────────────────────────────────────────────────────
quarkus.smallrye-health.ui.enable=true
quarkus.health.extensions.enabled=true
```

---

## Rules

- Log correlation IDs on every INFO/WARN/ERROR log line.
- Never call `System.out.println()` — always use `Logger`.
- Timers must use `histogram = true` for percentile reporting in Prometheus.
- Every public service method in domain-touching paths must have a `@Timed` or programmatic Timer.
- Health checks must be idempotent and complete within 2 seconds.
- Trace sampling at 100% only in development — use 10% in production.

---

## Checklist

```
[ ] SLF4J/JBoss Logger declared as private static final in every class that logs
[ ] Correlation ID filter registered and MDC populated
[ ] No PII in any log statement
[ ] At least one Timer on each public service method
[ ] At least one Counter for each error path
[ ] @Readiness check validates external dependency connectivity
[ ] application.properties has quarkus.log.console.json=true for prod profile
[ ] OTLP exporter endpoint configured for staging/prod profiles
[ ] /q/metrics endpoint accessible by Prometheus scraper
[ ] /q/health/live and /q/health/ready responding correctly
```
