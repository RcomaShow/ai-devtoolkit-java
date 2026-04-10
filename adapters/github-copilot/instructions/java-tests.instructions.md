---
description: 'JUnit 5 + Mockito 5 unit test standards for Quarkus microservices. Applied to all test Java files. Enforces strict mocking, meaningful assertions, and 100% branch coverage discipline.'
applyTo: 'src/test/java/**/*Test.java'
---

# Java Unit Tests — Standards

## Stack

**JUnit 5 + Mockito 5 ONLY.**

```java
// REQUIRED class-level annotation
@ExtendWith(MockitoExtension.class)

// NEVER use these
// @QuarkusTest
// @QuarkusIntegrationTest
// @Testcontainers
```

## Test Class Structure

```java
@ExtendWith(MockitoExtension.class)
class NominaServiceTest {

    // Constants for test data — avoid magic values
    private static final String CODICE = "NOM-2024-001";
    private static final Long ID = 1L;

    // Dependencies — all mocked via interface/port
    @Mock NominaRepository repository;
    @Mock NominaMapper mapper;

    // System under test — populated via @InjectMocks
    @InjectMocks NominaService sut;

    // === HAPPY PATHS ===

    @Test
    void should_returnDto_when_entityExists() { ... }

    // === ERROR PATHS ===

    @Test
    void should_throwNotFoundException_when_idMissing() { ... }

    // === BOUNDARY VALUES ===

    @Test
    void should_throwValidationException_when_dateRangeInvalid() { ... }
}
```

## Test Method Naming

```
should_<expectedOutcome>_when_<condition>()
```

Examples:
- `should_returnNominaDto_when_idExists()`
- `should_throwNotFoundException_when_entityNotFound()`
- `should_callRepository_when_createSucceeds()`

## ArgumentCaptor — Verify Before GetValue

```java
@Test
void should_persistWithCorrectData_when_createCalled() {
    // Arrange
    ArgumentCaptor<NominaEntity> captor = ArgumentCaptor.forClass(NominaEntity.class);
    when(mapper.toEntity(any())).thenReturn(new NominaEntity());

    // Act
    sut.create(new CreateNominaRequest(CODICE, LocalDate.now()));

    // Assert — ALWAYS verify before getValue()
    verify(repository).save(captor.capture());
    assertThat(captor.getValue().getCodice()).isEqualTo(CODICE);
}
```

## Mandatory Assertions

- Always use AssertJ: `assertThat(actual).isEqualTo(expected)`.
- Never write `assertTrue(true)` or `assertNotNull(result)` without follow-up field checks.
- Every test must be **falsifiable** — a specific bug must break it.

## Strict Mocking Rules

- `MockitoExtension` enforces strict stubs by default — do not stub what you don't call.
- Remove stubs that do not participate in the test under test.
- Use `@Disabled("TICKET-123: reason")` only when a test can't run — never leave empty bodies.

## When to Use Advanced Mockito

```java
// Multiple return values (consecutive calls)
when(repo.findById(ID)).thenReturn(Optional.of(entity)).thenReturn(Optional.empty());

// Dynamic return based on argument
when(mapper.toDomain(any())).thenAnswer(inv -> {
    NominaEntity e = inv.getArgument(0);
    return new Nomina(e.getCodice());
});

// Call order verification
InOrder inOrder = inOrder(repo, mapper);
inOrder.verify(repo).save(any());
inOrder.verify(mapper).toDto(any());
```

## Parameterized Tests for Boundaries

```java
@ParameterizedTest
@CsvSource({
    "null, 2024-01-01, 'codice is required'",
    "'', 2024-01-01, 'codice must not be blank'",
    "VALID, null, 'dataInizio is required'"
})
void should_rejectInvalidInput_when_requestIsInvalid(
        String codice, LocalDate dataInizio, String expectedMessage) { ... }
```
