---
name: tdd-workflow
description: "Test-Driven Development workflow using JUnit 5 + Mockito 5. NO @QuarkusTest, NO @QuarkusIntegrationTest, NO Testcontainers in unit tests. Reference when writing tests for any layer of a Quarkus microservice."
argument-hint: "Test scenario — e.g. 'domain service test', 'application service mock test', 'REST resource layer test'"
user-invocable: false
---

# TDD Workflow — JUnit 5 + Mockito

> **RULE**: Use **JUnit 5 + Mockito 5 only** for unit tests.
> `@QuarkusTest`, `@QuarkusIntegrationTest`, Testcontainers spin-up, and RestAssured are **NOT USED**.

## Test Stack

| Dependency | Role |
|------------|------|
| `junit-jupiter` 5.x | Test framework — `@Test`, `@ParameterizedTest`, `@ExtendWith` |
| `mockito-core` 5.x | Mocking — `@Mock`, `@InjectMocks`, `when().thenReturn()` |
| `mockito-junit-jupiter` | JUnit 5 Mockito extension — `MockitoExtension.class` |
| `assertj-core` 3.x | Fluent assertions — `assertThat(actual).isEqualTo(expected)` |

## Test Class Structure

```java
// NO @QuarkusTest
@ExtendWith(MockitoExtension.class)              // ← Mockito JUnit 5 extension
class {Entity}ServiceTest {

    @Mock {Entity}Repository {entity}Repository; // mock the port interface
    @Mock {Entity}Mapper mapper;

    @InjectMocks {Entity}Service {entity}Service; // injects the mocks above

    // --- HAPPY PATH ---

    @Test
    void should_create{Entity}_when_requestIsValid() {
        // Arrange
        var request = new Create{Entity}Request(/* valid data */);
        var domain = new {Entity}(/* ... */);
        var saved  = new {Entity}(/* with id */);
        var expectedDto = new {Entity}Dto(/* ... */);

        when(mapper.toDomain(request)).thenReturn(domain);
        when({entity}Repository.save(domain)).thenReturn(saved);
        when(mapper.toDto(saved)).thenReturn(expectedDto);

        // Act
        var result = {entity}Service.create(request);

        // Assert
        assertThat(result).isEqualTo(expectedDto);
        verify({entity}Repository).save(domain);
    }

    // --- ERROR PATHS ---

    @Test
    void should_throwDomainException_when_dataIsInvalid() {
        var request = new Create{Entity}Request(/* invalid data */);
        doThrow(new DomainValidationException("Invalid")).when(mapper).toDomain(request);

        assertThatThrownBy(() -> {entity}Service.create(request))
            .isInstanceOf(DomainValidationException.class);

        verifyNoInteractions({entity}Repository);
    }
}
```

## Test Naming Convention

```
should_<expectedBehaviour>_when_<condition>
```

Examples:
- `should_return{Entity}_when_idExists`
- `should_throwNotFoundException_when_idNotFound`
- `should_returnEmpty_when_noneInPeriod`
- `should_calculateMinCapacity_when_limitExceeded`

## Testing Domain Services

Domain services have **no framework dependencies** — test them with plain JUnit 5, mocking only port interfaces.

```java
@ExtendWith(MockitoExtension.class)
class {Domain}DomainServiceTest {

    @Mock {Port}Port {port}Port;

    @InjectMocks {Domain}DomainService domainService;

    @Test
    void should_applyBusinessRule_when_conditionMet() {
        var input = /* build domain object */;
        when({port}Port.get{Data}(any())).thenReturn(/* test value */);

        var result = domainService.process(input);

        assertThat(result.someField()).isEqualTo(/* expected */);
    }

    @ParameterizedTest(name = "input={0} → expected={1}")
    @CsvSource({
        "100, 60",
        "50,  50",
        "0,   0"
    })
    void should_respectFormula(int input, int expected) {
        var result = domainService.calculate(input);
        assertThat(result).isEqualByComparingTo(String.valueOf(expected));
    }
}
```

## Testing Application Services (with mocked ports)

```java
@ExtendWith(MockitoExtension.class)
class {Entity}ServiceTest {

    @Mock {Entity}Repository {entity}Repository;
    @Mock ExternalServiceClient externalClient; // external call — always mock
    @Mock {Entity}Mapper mapper;

    @InjectMocks {Entity}Service {entity}Service;

    @Test
    void should_completeProcess_when_allConditionsMet() {
        var id = new {Entity}Id(1L);
        var entity = {Entity}Builder.open().withId(id).build();

        when({entity}Repository.findById(id)).thenReturn(Optional.of(entity));
        when(externalClient.checkStatus(id)).thenReturn(true);

        {entity}Service.process(id);

        verify({entity}Repository).save(entity);
    }
}
```

## Testing REST Resources (no Quarkus CDI needed)

```java
// Test the resource class directly — it's just a Java object
@ExtendWith(MockitoExtension.class)
class {Entity}ResourceTest {

    @Mock {Entity}Service {entity}Service;
    @InjectMocks {Entity}Resource resource;

    @Test
    void should_return201_when_{entity}Created() {
        var request = validRequest();
        var dto = new {Entity}Dto(42L, /* ... */);
        var uriInfo = mock(UriInfo.class);
        var builder = mock(UriBuilder.class);

        when({entity}Service.create(request)).thenReturn(dto);
        when(uriInfo.getAbsolutePathBuilder()).thenReturn(builder);
        when(builder.path("42")).thenReturn(builder);
        when(builder.build()).thenReturn(URI.create("/api/v1/{entities}/42"));

        var response = resource.create(request, uriInfo);

        assertThat(response.getStatus()).isEqualTo(201);
        assertThat(response.getEntity()).isEqualTo(dto);
    }
}
```

## Testing Value Objects

Value Objects have no external dependencies — pure unit tests.

```java
class PeriodTest {

    @Test
    void should_throw_when_endBeforeStart() {
        assertThatThrownBy(() -> new Period(LocalDate.now(), LocalDate.now().minusDays(1)))
            .isInstanceOf(DomainException.class);
    }

    @Test
    void should_detectOverlap() {
        var p1 = new Period(LocalDate.of(2024, 1, 1), LocalDate.of(2024, 1, 31));
        var p2 = new Period(LocalDate.of(2024, 1, 15), LocalDate.of(2024, 2, 15));
        assertThat(p1.overlaps(p2)).isTrue();
    }
}
```

## Test File Placement

```
src/
  main/java/com/company/{domain}/
  test/java/com/company/{domain}/
    domain/
      model/          PeriodTest, AmountTest, {Entity}Test
      service/        {Domain}DomainServiceTest
    service/          {Entity}ServiceTest
    api/              {Entity}ResourceTest
    data/
      acl/            {Entity}AclTranslatorTest
    mapping/          {Entity}MapperTest
```

## Mockito Patterns Quick Reference

```java
// Stub return value
when(repo.findById(id)).thenReturn(Optional.of(entity));

// Stub void — use doNothing/doThrow
doNothing().when(validator).validate(any());
doThrow(new DomainException("...")).when(validator).validate(invalidRequest);

// Capture arguments
var captor = ArgumentCaptor.forClass({Entity}.class);
verify(repo).save(captor.capture());
assertThat(captor.getValue().getStatus()).isEqualTo({Status}.ACTIVE);

// Verify interaction count
verify(repo, times(1)).save(any());
verify(repo, never()).delete(any());
verifyNoMoreInteractions(repo);
```

## TDD Cycle

1. **Red** — write a failing test that specifies the behaviour
2. **Green** — write the minimum implementation to make it pass
3. **Refactor** — clean up without breaking tests

For each acceptance criterion:
1. Translate the AC into a test method name: `should_<AC_outcome>_when_<AC_condition>`
2. Write the test body first (arrange/act/assert)
3. Let the compiler guide interface/class creation
4. Implement to make green
5. Add edge case + error path tests
