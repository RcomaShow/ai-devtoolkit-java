---
name: quarkus-backend/async
description: "Async and event-driven patterns for Quarkus 3.x: Mutiny Uni/Multi, SSE streaming, CDI domain events. Load this when adding reactive or event-driven behavior to a service."
argument-hint: "Async pattern needed — e.g. 'Uni return type', 'SSE stream', 'CDI observer', 'async create'"
user-invocable: false
---

# Quarkus Async & Event Patterns

> Use async only when blocking is genuinely unacceptable (external I/O > 200ms, SSE streaming, fan-out).
> For standard CRUD with Oracle/MSSQL, the **blocking thread model** (default Quarkus) is simpler and correct.

---

## When to Use Async

| Situation | Pattern |
|-----------|---------|
| Long-running external HTTP call (> 200ms) | `Uni<T>` return type |
| Server-Sent Events / live data stream | `Multi<T>` with SSE |
| Fire-and-forget notification (audit, email) | CDI `Event<T>.fireAsync()` |
| Fan-out: call N services in parallel | `Uni.combine().all().unis(...)` |
| Background periodic job | `@Scheduled` (blocking, use `@Blocking` if needed) |
| Real-time messaging across services | SmallRye Reactive Messaging + Kafka channel |

---

## Mutiny Uni — Single Async Value

```java
import io.smallrye.mutiny.Uni;

@Path("/api/v1/{entities}/async")
public class {Entity}AsyncResource {

    private final {Entity}Service {entity}Service;
    public {Entity}AsyncResource({Entity}Service s) { this.{entity}Service = s; }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @APIResponse(responseCode = "202", description = "Accepted for processing")
    public Uni<Response> createAsync(@Valid Create{Entity}Request request) {
        return {entity}Service.createAsync(request)
            .map(dto -> Response.accepted().entity(dto).build());
    }

    @GET
    @Path("/{id}")
    public Uni<Response> getByIdAsync(@PathParam("id") Long id) {
        return {entity}Service.findByIdAsync(id)
            .map(dto -> Response.ok(dto).build())
            .onFailure({Entity}NotFoundException.class)
                .recoverWithItem(Response.status(404).build());
    }
}

@ApplicationScoped
public class {Entity}Service {

    public Uni<{Entity}Dto> createAsync(Create{Entity}Request request) {
        return Uni.createFrom()
            .item(() -> doCreate(request))          // blocking work wrapped in Uni
            .runSubscriptionOn(Infrastructure.getDefaultWorkerPoolExecutor());
    }

    public Uni<{Entity}Dto> findByIdAsync(Long id) {
        return Uni.createFrom()
            .optional(() -> {entity}Repository.findById(new {Entity}Id(id)).map(mapper::toDto))
            .onItem().ifNull().failWith(() -> new {Entity}NotFoundException(id));
    }
}
```

---

## Mutiny Uni — Parallel Fan-out

```java
// Call two services in parallel, combine results
public Uni<CombinedResult> fetchCombined(Long id) {
    var entityUni   = {entity}Service.findByIdAsync(id);
    var externalUni = externalClient.fetchDataAsync(id);

    return Uni.combine().all()
        .unis(entityUni, externalUni)
        .asTuple()
        .map(tuple -> new CombinedResult(tuple.getItem1(), tuple.getItem2()));
}

// Retry on transient failure
public Uni<{Entity}Dto> fetchWithRetry(Long id) {
    return externalClient.fetchAsync(id)
        .onFailure(TransientException.class)
            .retry()
            .withBackOff(Duration.ofMillis(200), Duration.ofSeconds(2))
            .atMost(3);
}

// Timeout
public Uni<{Entity}Dto> fetchWithTimeout(Long id) {
    return externalClient.fetchAsync(id)
        .ifNoItem().after(Duration.ofSeconds(5))
        .failWith(new TimeoutException("external service timeout"));
}
```

---

## Mutiny Multi — SSE Streaming

```java
import io.smallrye.mutiny.Multi;

@Path("/api/v1/{entities}/stream")
public class {Entity}StreamResource {

    private final {Entity}Service {entity}Service;
    public {Entity}StreamResource({Entity}Service s) { this.{entity}Service = s; }

    @GET
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @SseElementType(MediaType.APPLICATION_JSON)
    public Multi<{Entity}Dto> stream(
            @QueryParam("status") String status) {
        return {entity}Service.streamByStatus(status);
    }
}

@ApplicationScoped
public class {Entity}Service {

    public Multi<{Entity}Dto> streamByStatus(String status) {
        return Multi.createFrom()
            .iterable(() -> {entity}Repository.findByStatus(status))
            .map(mapper::toDto)
            .onFailure().invoke(e -> LOG.errorf(e, "Error streaming {entities}"));
    }

    // Periodic stream (e.g. live metrics)
    public Multi<{Entity}Dto> streamLive() {
        return Multi.createFrom().ticks()
            .every(Duration.ofSeconds(5))
            .onItem().transformToUniAndMerge(tick ->
                Uni.createFrom().item(() -> fetchCurrent())
            );
    }
}
```

---

## CDI Domain Events (Synchronous)

Use for within-service notifications (audit, side-effects) that must be in the same transaction:

```java
// 1. Define the event (immutable record)
public record {Entity}CreatedEvent(
    Long    id,
    String  code,
    Instant occurredAt
) {
    public static {Entity}CreatedEvent of({Entity} entity) {
        return new {Entity}CreatedEvent(entity.id().value(), entity.code(), Instant.now());
    }
}

// 2. Service fires the event
@ApplicationScoped
public class {Entity}Service {

    @Inject
    Event<{Entity}CreatedEvent> createdEventBus;

    @Transactional
    public {Entity}Dto create(Create{Entity}Request request) {
        var domain = mapper.toDomain(request);
        var saved  = {entity}Repository.save(domain);
        createdEventBus.fire({Entity}CreatedEvent.of(saved));    // synchronous, same TX
        return mapper.toDto(saved);
    }
}

// 3. Observer reacts
@ApplicationScoped
public class {Entity}AuditListener {

    private static final Logger LOG = Logger.getLogger({Entity}AuditListener.class);

    void on{Entity}Created(@Observes {Entity}CreatedEvent event) {
        LOG.infof("Audit: {entity} created id=%d at=%s", event.id(), event.occurredAt());
        // write to audit table — runs inside the same @Transactional
    }
}
```

---

## CDI Events — Async (Fire and Forget)

Use when the side-effect must NOT block the main flow and can tolerate failure:

```java
// Fire asynchronously (leaves the current transaction)
createdEventBus.fireAsync({Entity}CreatedEvent.of(saved))
    .exceptionally(e -> {
        LOG.errorf(e, "Async event delivery failed");
        return null;
    });

// Observer for async events
void on{Entity}CreatedAsync(@ObservesAsync {Entity}CreatedEvent event) {
    // runs in a separate thread — no access to the original transaction
    emailService.notifyTeam(event);
}
```

---

## SmallRye Reactive Messaging (Kafka)

For cross-service async messaging — use only when CDI events are insufficient:

```java
// Producer
@ApplicationScoped
public class {Entity}EventProducer {

    @Channel("{entity}-created")
    Emitter<{Entity}CreatedEvent> emitter;

    public void publish({Entity}CreatedEvent event) {
        emitter.send(Message.of(event)
            .withAck(() -> {
                LOG.debugf("Event ack: {entity} id=%d", event.id());
                return CompletableFuture.completedFuture(null);
            }));
    }
}

// Consumer (in another service)
@ApplicationScoped
public class {Entity}CreatedConsumer {

    @Incoming("{entity}-created")
    public void onCreated({Entity}CreatedEvent event) {
        // idempotent processing — may receive duplicates
    }
}
```

```properties
# application.properties
mp.messaging.outgoing.{entity}-created.connector=smallrye-kafka
mp.messaging.outgoing.{entity}-created.topic={entity}.created.v1
mp.messaging.outgoing.{entity}-created.value.serializer=io.quarkus.kafka.client.serialization.JsonbSerializer

mp.messaging.incoming.{entity}-created.connector=smallrye-kafka
mp.messaging.incoming.{entity}-created.topic={entity}.created.v1
mp.messaging.incoming.{entity}-created.value.deserializer=com.company.{domain}.{Entity}CreatedEventDeserializer
mp.messaging.incoming.{entity}-created.group.id={service}-consumer-group
```

---

## Rules

- **Default to blocking** — only introduce `Uni`/`Multi` when a real async requirement exists.
- **Never mix** `@Transactional` with `Uni` return types directly — transactions don't propagate into reactive pipelines automatically.
- **Always handle failures** on async events — unhandled exceptions in `fireAsync` are silently dropped.
- **CDI sync events** share the caller's transaction — observers can write to the DB.
- **CDI async events** are outside the transaction — observers cannot roll back the original operation.
- **Kafka consumers** must be idempotent — at-least-once delivery means duplicates will occur.
