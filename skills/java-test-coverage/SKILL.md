---
name: java-test-coverage
description: 'Systematic procedure for achieving 100% meaningful branch coverage on Java classes using JUnit 5 + Mockito 5. Includes path enumeration, test case matrix, test data builders, and advanced Mockito patterns.'
argument-hint: "Class to cover — e.g. '{Entity}Service', 'REST resource with pagination'"
user-invocable: false
---

# Java Test Coverage — Systematic Path Analysis

> **Goal**: 100% branch coverage. Line coverage is a consequence, not a target.
> **Stack**: JUnit 5 + Mockito 5 + AssertJ. NO @QuarkusTest, NO Testcontainers.

---

## Phase 1 — Path Enumeration

For **every method** in the target class, enumerate all paths before writing a single test.

### Branch Source Checklist

```
For each method:
  [ ] Happy path (all conditions satisfied, no exceptions)
  [ ] Each null/empty parameter (separately)
  [ ] Each @NotNull / @Valid annotation failure
  [ ] Each `if` condition — true branch AND false branch
  [ ] Each `else if` branch
  [ ] Each `switch` case (including `default`)
  [ ] Each ternary `? :` — true side AND false side
  [ ] Each `Optional.orElse` / `Optional.orElseThrow` — present AND empty
  [ ] Each `for`/`for-each` loop — zero iterations AND at least one iteration
  [ ] Each `while`/`do-while` — zero iterations AND multiple
  [ ] Each checked exception thrown by dependencies
  [ ] Each RuntimeException thrown by dependencies
  [ ] Each early-return guard clause (the guard fires AND it doesn't)
```

### Path Matrix Template

Fill one row per path before coding:

```markdown
| # | Method | Branch / Path | Mocks Needed | Expected Result | Test Method Name |
|---|--------|--------------|--------------|-----------------|-----------------|
| 1 | create() | Happy path | mapper.toDomain, repo.save, mapper.toDto | returns saved dto | should_create{Entity}_when_requestIsValid |
| 2 | create() | mapper.toDomain throws DomainValidationException | mapper | exception propagates | should_throwDomainException_when_mappingFails |
| 3 | findById() | entity found | repo.findById → Optional.of | returns dto | should_return{Entity}_when_idExists |
| 4 | findById() | entity not found | repo.findById → Optional.empty() | throws NotFoundException | should_throwNotFound_when_idMissing |
| 5 | findById() | null id | — | throws NullPointerException | should_throwNullPointer_when_idIsNull |
```

---

## Phase 2 — Test Data Builders

Never construct test objects inline when the same object type appears in 3+ tests. Use a builder.

```java
// Builder pattern for test-only construction
// Place in: src/test/java/com/company/{domain}/domain/model/{Entity}Builder.java
public final class {Entity}Builder {

    private {Entity}Id id        = new {Entity}Id(1L);
    private String      code     = "DEFAULT_CODE";
    private LocalDate   dateFrom = LocalDate.of(2024, 1, 1);
    private LocalDate   dateTo   = LocalDate.of(2024, 12, 31);
    private {Status}    status   = {Status}.ACTIVE;

    private {Entity}Builder() {}

    public static {Entity}Builder defaults() {
        return new {Entity}Builder();
    }

    public {Entity}Builder withId({Entity}Id id) {
        this.id = id;
        return this;
    }
    public {Entity}Builder withCode(String code) {
        this.code = code;
        return this;
    }
    public {Entity}Builder withStatus({Status} status) {
        this.status = status;
        return this;
    }
    public {Entity}Builder withPeriod(LocalDate from, LocalDate to) {
        this.dateFrom = from;
        this.dateTo   = to;
        return this;
    }

    public {Entity} build() {
        return new {Entity}(id, code, dateFrom, dateTo, status);
    }
}
```

Usage in tests:
```java
// Minimal — use all defaults
var entity = {Entity}Builder.defaults().build();

// Specific scenario
var expiredEntity = {Entity}Builder.defaults()
    .withStatus({Status}.EXPIRED)
    .withPeriod(LocalDate.of(2023, 1, 1), LocalDate.of(2023, 12, 31))
    .build();
```

---

## Phase 3 — Test Class Skeleton

```java
@ExtendWith(MockitoExtension.class)     // strict stubs — unused stubs fail the test
class {Entity}ServiceTest {

    // ── Mocks ──────────────────────────────────────────────────────────────────
    @Mock {Entity}Repository {entity}Repository;
    @Mock {Entity}Mapper      mapper;
    @Mock ExternalServiceClient externalClient; // only if the class has this dep

    // ── Captor ─────────────────────────────────────────────────────────────────
    @Captor ArgumentCaptor<{Entity}> savedEntityCaptor;

    // ── System under test ──────────────────────────────────────────────────────
    @InjectMocks {Entity}Service sut;           // "sut" = system under test

    // ── Test data ──────────────────────────────────────────────────────────────
    private static final {Entity}Id EXISTING_ID   = new {Entity}Id(42L);
    private static final {Entity}Id MISSING_ID    = new {Entity}Id(99L);
    private static final String     VALID_CODE    = "CODE_001";

    // ─────────────────────────────────────────────────────────────────────────
    // Happy paths
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    void should_create{Entity}_when_requestIsValid() {
        var request   = new Create{Entity}Request(VALID_CODE, LocalDate.now(), LocalDate.now().plusDays(30));
        var domain    = {Entity}Builder.defaults().withCode(VALID_CODE).build();
        var savedEntity = {Entity}Builder.defaults().withCode(VALID_CODE).build();
        var expectedDto = new {Entity}Dto(EXISTING_ID.value(), VALID_CODE);

        when(mapper.toDomain(request)).thenReturn(domain);
        when({entity}Repository.save(domain)).thenReturn(savedEntity);
        when(mapper.toDto(savedEntity)).thenReturn(expectedDto);

        var result = sut.create(request);

        assertThat(result).isEqualTo(expectedDto);
        verify({entity}Repository).save(domain);
    }

    @Test
    void should_return{Entity}_when_idExists() {
        var entity = {Entity}Builder.defaults().withId(EXISTING_ID).build();
        var expectedDto = new {Entity}Dto(EXISTING_ID.value(), VALID_CODE);

        when({entity}Repository.findById(EXISTING_ID)).thenReturn(Optional.of(entity));
        when(mapper.toDto(entity)).thenReturn(expectedDto);

        var result = sut.findById(EXISTING_ID.value());

        assertThat(result).contains(expectedDto);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Error paths
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    void should_throwNotFound_when_idMissing() {
        when({entity}Repository.findById(MISSING_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> sut.findById(MISSING_ID.value()))
            .isInstanceOf({Entity}NotFoundException.class)
            .hasMessageContaining(String.valueOf(MISSING_ID.value()));

        verifyNoMoreInteractions(mapper);
    }

    @Test
    void should_throwDomainException_when_mappingFails() {
        var request = new Create{Entity}Request(/* invalid data */);
        doThrow(new DomainValidationException("invalid code"))
            .when(mapper).toDomain(request);

        assertThatThrownBy(() -> sut.create(request))
            .isInstanceOf(DomainValidationException.class);

        verifyNoInteractions({entity}Repository);
    }

    @Test
    void should_throwNullPointer_when_idIsNull() {
        assertThatNullPointerException()
            .isThrownBy(() -> sut.findById(null));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Boundary values (add per domain)
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    void should_returnEmpty_when_noneInPeriod() {
        when({entity}Repository.findByPeriod(any(), any())).thenReturn(Collections.emptyList());

        var result = sut.findByPeriod(LocalDate.now(), LocalDate.now().plusDays(10));

        assertThat(result).isEmpty();
    }
}
```

---

## Phase 4 — Advanced Mockito Patterns

### ArgumentCaptor — Verify Saved State

Use when the method's observable effect is what it **passes** to a dependency:

```java
@Captor ArgumentCaptor<{Entity}> captor;

@Test
void should_saveEntityWithCorrectStatus_when_activating() {
    var id = new {Entity}Id(1L);
    when({entity}Repository.findById(id))
        .thenReturn(Optional.of({Entity}Builder.defaults().withStatus({Status}.DRAFT).build()));

    sut.activate(id);

    verify({entity}Repository).save(captor.capture());             // capture BEFORE getValue
    assertThat(captor.getValue().status()).isEqualTo({Status}.ACTIVE);
}
```

### Spy — Partial Mocking

Use only when the class has a mix of real logic and framework-delegating methods:

```java
@Test
void should_callExternalOnce_when_retrySucceeds() {
    var realService = new {Entity}Service({entity}Repository, mapper);
    var spyService  = spy(realService);

    doReturn(true)
        .doThrow(new TransientException())  // first call throws, second succeeds (or vice versa)
        .when(spyService).callExternal(any());

    spyService.processWithRetry(someRequest);

    verify(spyService, times(2)).callExternal(any());
}
```

### Strict Stubs — Detect Unused Mocks

`MockitoExtension` enforces strict stubs by default: if you declare `when()` but the method is never called, the test fails. This prevents test rot.

```java
// This will FAIL with strict stubs if `externalClient.check()` is never called:
when(externalClient.check(any())).thenReturn(true);
// Fix: remove the stub, or fix the code path to call it
```

### Verify Order — When Sequence Matters

```java
@Test
void should_validateBeforePersisting() {
    var order = inOrder({entity}Repository, mapper);

    sut.create(request);

    order.verify(mapper).toDomain(request);                      // must happen first
    order.verify({entity}Repository).save(any());               // then persist
    order.verifyNoMoreInteractions();
}
```

### Multiple Return Values

```java
// First call returns A, second call returns B
when({entity}Repository.findById(id))
    .thenReturn(Optional.of(entity))                             // first call
    .thenReturn(Optional.empty());                              // second call

// Throw on second invocation
when(externalClient.fetch(id))
    .thenReturn(result)
    .thenThrow(new TimeoutException());
```

### Answer — Dynamic Return Values

```java
// Return a modified version of the input
when({entity}Repository.save(any({Entity}.class)))
    .thenAnswer(invocation -> {
        var entity = invocation.getArgument(0, {Entity}.class);
        return new {Entity}(new {Entity}Id(99L), entity.code(), entity.status());
    });
```

---

## Phase 5 — Layer-Specific Patterns

### Domain Model (Value Object)

No mocks needed — pure constructor validation:

```java
class {Entity}IdTest {

    @Test
    void should_throw_when_idIsNegative() {
        assertThatIllegalArgumentException()
            .isThrownBy(() -> new {Entity}Id(-1L))
            .withMessageContaining("negative");
    }

    @Test
    void should_create_when_idIsPositive() {
        var id = new {Entity}Id(1L);
        assertThat(id.value()).isEqualTo(1L);
    }

    @Test
    void should_beEqual_when_sameValue() {
        var a = new {Entity}Id(1L);
        var b = new {Entity}Id(1L);
        assertThat(a).isEqualTo(b);
        assertThat(a.hashCode()).isEqualTo(b.hashCode());
    }
}
```

### ACL Translator

Tests are structural — verify field mapping correctness:

```java
@ExtendWith(MockitoExtension.class)
class {Entity}AclTranslatorTest {

    {Entity}AclTranslator translator = new {Entity}AclTranslator();

    @Test
    void should_mapAllFields_when_convertingToDomain() {
        var entity = new {Entity}Entity();
        entity.id      = 42L;
        entity.codValue = "TEST";
        entity.status  = "ACTIVE";

        var domain = translator.toDomain(entity);

        assertThat(domain.id().value()).isEqualTo(42L);
        assertThat(domain.code()).isEqualTo("TEST");
        assertThat(domain.status()).isEqualTo({Status}.ACTIVE);
    }

    @Test
    void should_mapNullableField_when_fieldIsNull() {
        var entity = new {Entity}Entity();
        entity.id        = 1L;
        entity.optionalField = null;

        var domain = translator.toDomain(entity);

        assertThat(domain.optionalField()).isNull();  // or: isEmpty() if Optional
    }
}
```

### REST Resource

Test HTTP contract without Quarkus CDI:

```java
@ExtendWith(MockitoExtension.class)
class {Entity}ResourceTest {

    @Mock {Entity}Service {entity}Service;
    @InjectMocks {Entity}Resource sut;

    @Test
    void should_return201WithLocation_when_created() {
        var request  = validRequest();
        var dto      = new {Entity}Dto(99L, "CODE");
        var uriInfo  = mock(UriInfo.class);
        var builder  = mock(UriBuilder.class);

        when({entity}Service.create(request)).thenReturn(dto);
        when(uriInfo.getAbsolutePathBuilder()).thenReturn(builder);
        when(builder.path("99")).thenReturn(builder);
        when(builder.build()).thenReturn(URI.create("/api/v1/{entities}/99"));

        var response = sut.create(request, uriInfo);

        assertThat(response.getStatus()).isEqualTo(201);
        assertThat(response.getLocation().toString()).endsWith("/99");
    }

    @Test
    void should_return404_when_notFound() {
        when({entity}Service.findById(99L)).thenThrow(new {Entity}NotFoundException(99L));

        assertThatThrownBy(() -> sut.getById(99L))
            .isInstanceOf({Entity}NotFoundException.class);
    }

    private static Create{Entity}Request validRequest() {
        return new Create{Entity}Request("CODE", LocalDate.now(), LocalDate.now().plusDays(30));
    }
}
```

---

## Phase 6 — Parameterized Tests

Use `@ParameterizedTest` when the same assertion applies to multiple inputs:

```java
@ParameterizedTest(name = "code={0} → valid={1}")
@CsvSource({
    "CODE_001, true",
    "'',       false",
    "X,        false",    // too short
    "A_123456789012345678901, false"  // too long
})
void should_validateCodeFormat(String code, boolean expectedValid) {
    assertThat({Entity}CodeValidator.isValid(code)).isEqualTo(expectedValid);
}

// Enum cases
@ParameterizedTest
@EnumSource(value = {Status}.class, names = {"DRAFT", "CANCELLED"})
void should_throwTransitionException_when_activatingFromFinalStatus({Status} finalStatus) {
    var entity = {Entity}Builder.defaults().withStatus(finalStatus).build();

    assertThatThrownBy(() -> entity.activate())
        .isInstanceOf(IllegalStateTransitionException.class);
}
```

---

## Checklist — Before Marking a Test as Complete

```
[ ] The test has exactly ONE assertion target (one reason to fail)
[ ] The test name follows: should_<outcome>_when_<condition>
[ ] Every mock stub is actually exercised (strict stubs will catch this)
[ ] Verify() is called where side effects matter
[ ] No Thread.sleep(), no @Disabled, no System.out.println() in the test
[ ] The test passes in isolation (no shared state between tests)
[ ] Running the test 100 times produces the same result (no flakiness)
[ ] Removing the implementation line this test targets causes the test to fail
```

---

## Mutation Testing Reference (Advanced)

After reaching 100% branch coverage, run mutation testing to verify tests are meaningful:

```bash
# PIT mutation testing (Maven)
mvn org.pitest:pitest-maven:mutationCoverage \
  -DtargetClasses="com.company.{domain}.**" \
  -DtargetTests="com.company.{domain}.**Test"

# Expect: mutation score > 85%
# Low score = tests that pass even when implementation is broken
```

Key mutation types to survive:
- **Conditional boundary** (`>` mutated to `>=`) — test boundary values explicitly
- **Negate conditional** (`if (a)` → `if (!a)`) — both branches must be tested
- **Remove method calls** (`repo.save(x)` removed) — use `verify()` for side effects
- **Return value substitution** (`return x` → `return null`) — assert exact return values
