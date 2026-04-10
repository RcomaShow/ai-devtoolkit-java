---
name: quarkus-backend-persistence
description: 'Persistence layer patterns for Quarkus 3.x: Panache Entity, Repository implementation, ACL Translator, pagination, multi-datasource Oracle + MSSQL. Load this when writing the data layer.'
argument-hint: "Persistence pattern needed — e.g. 'Panache entity', 'repository with ACL', 'pagination', 'named datasource'"
user-invocable: false
---

# Quarkus Persistence Layer Patterns

---

## Panache Entity (Data Layer Only)

JPA entities **never** leave the `data/` package. Domain objects are the API to the rest of the system.

```java
@Entity
@Table(name = "T_{ENTITY}", indexes = {
    @Index(name = "IDX_{ENTITY}_COD",    columnList = "COD_VALUE"),
    @Index(name = "IDX_{ENTITY}_STATUS", columnList = "FLG_STATUS")
})
public class {Entity}Entity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "{entity}_seq")
    @SequenceGenerator(name = "{entity}_seq", sequenceName = "SEQ_{ENTITY}", allocationSize = 1)
    public Long id;

    @Column(name = "COD_VALUE", nullable = false, length = 20)
    public String codValue;

    @Column(name = "DT_INIZIO", nullable = false)
    public LocalDate dtInizio;

    @Column(name = "DT_FINE", nullable = false)
    public LocalDate dtFine;

    @Column(name = "FLG_STATUS", nullable = false, length = 20)
    public String flgStatus;

    @Column(name = "QT_AMOUNT", precision = 12, scale = 2)
    public BigDecimal qtAmount;

    @Version                               // optimistic locking
    public Long version;

    // FK to parent
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ID_PARENT", nullable = false)
    public {Parent}Entity parent;

    // One-to-many children
    @OneToMany(mappedBy = "parent", cascade = CascadeType.ALL, orphanRemoval = true)
    public List<{Child}Entity> children = new ArrayList<>();
}
```

---

## Panache Entity Repository (Inner DAO)

```java
@ApplicationScoped
public class {Entity}EntityRepository
        implements PanacheRepository<{Entity}Entity, Long> {

    // Named queries — prefer JPQL over native SQL
    public List<{Entity}Entity> findByStatusAndPeriod(String status,
                                                       LocalDate from,
                                                       LocalDate to) {
        return find("flgStatus = ?1 AND dtInizio <= ?2 AND dtFine >= ?3",
                    status, to, from)
            .list();
    }

    // Paginated
    public PanacheQuery<{Entity}Entity> findByStatus(String status) {
        return find("flgStatus = ?1 ORDER BY id DESC", status);
    }

    // Count
    public long countActive() {
        return count("flgStatus", "ACTIVE");
    }

    // Existence check
    public boolean existsByCode(String code) {
        return count("codValue", code) > 0;
    }
}
```

---

## Port Implementation (PanacheRepository → Domain Port)

```java
@ApplicationScoped
public class {Entity}PanacheRepository implements {Entity}Repository {

    private final {Entity}EntityRepository entityRepo;
    private final {Entity}AclTranslator    translator;

    public {Entity}PanacheRepository({Entity}EntityRepository entityRepo,
                                      {Entity}AclTranslator translator) {
        this.entityRepo  = entityRepo;
        this.translator  = translator;
    }

    @Override
    public Optional<{Entity}> findById({Entity}Id id) {
        return entityRepo.findByIdOptional(id.value())
            .map(translator::toDomain);
    }

    @Override
    public {Entity} save({Entity} domain) {
        var entity = translator.toEntity(domain);
        if (entity.id == null) {
            entityRepo.persist(entity);
        } else {
            entity = entityRepo.getEntityManager().merge(entity);
        }
        return translator.toDomain(entity);
    }

    @Override
    public void delete({Entity} domain) {
        entityRepo.deleteById(domain.id().value());
    }

    @Override
    public List<{Entity}> findByFilter(List{Entity}Request params) {
        return entityRepo.findByStatusAndPeriod(params.status(), params.dateFrom(), params.dateTo())
            .stream()
            .map(translator::toDomain)
            .toList();
    }

    @Override
    public PagedResult<{Entity}> findPaged(int page, int size, String sortBy) {
        var query = entityRepo.findAll(Sort.by(sortBy));
        var panachePage = query.page(page, size);
        return PagedResult.of(
            panachePage.list().stream().map(translator::toDomain).toList(),
            panachePage.count(),
            page,
            size
        );
    }
}
```

---

## ACL Translator (Domain ↔ Entity)

The ACL Translator is the boundary between the domain model and the persistence model. It belongs in `data/acl/`.

```java
@ApplicationScoped
public class {Entity}AclTranslator {

    // Entity → Domain (read path)
    public {Entity} toDomain({Entity}Entity e) {
        return new {Entity}(
            new {Entity}Id(e.id),
            e.codValue,
            e.dtInizio,
            e.dtFine,
            {Status}.valueOf(e.flgStatus),
            e.qtAmount
        );
    }

    // Domain → Entity (write path)
    public {Entity}Entity toEntity({Entity} domain) {
        var e = domain.id() != null
            ? findExistingOrNew(domain.id().value())  // update: start from existing
            : new {Entity}Entity();                    // create: fresh entity

        e.codValue  = domain.code();
        e.dtInizio  = domain.dateFrom();
        e.dtFine    = domain.dateTo();
        e.flgStatus = domain.status().name();
        e.qtAmount  = domain.amount();
        return e;
    }

    private {Entity}Entity findExistingOrNew(Long id) {
        // For updates, the entity must already be managed by the EntityManager
        // This is called inside a @Transactional context
        return new {Entity}Entity();  // replaced with entityManager.find() if needed
    }
}
```

**ACL rules:**
- ACL Translator is the ONLY class allowed to reference both `{Entity}` (domain) and `{Entity}Entity` (JPA).
- No business logic in the translator — pure field mapping only.
- If a domain field has no direct entity equivalent, the translation goes through a lookup method, not inline logic.

---

## Pagination Pattern

```java
// Domain result wrapper (in domain/port/)
public record PagedResult<T>(
    List<T> content,
    long    totalElements,
    int     totalPages,
    int     currentPage,
    int     pageSize,
    boolean hasNext,
    boolean hasPrevious
) {
    public static <T> PagedResult<T> of(List<T> content, long total, int page, int size) {
        int totalPages = size == 0 ? 0 : (int) Math.ceil((double) total / size);
        return new PagedResult<>(
            content, total, totalPages, page, size,
            page < totalPages - 1,
            page > 0
        );
    }
}

// Service returns PagedResult<{Entity}Dto>
public PagedResult<{Entity}Dto> listPaged(List{Entity}Request params) {
    var paged = {entity}Repository.findPaged(params.page(), params.pageSize(), params.sortBy());
    return new PagedResult<>(
        paged.content().stream().map(mapper::toDto).toList(),
        paged.totalElements(),
        paged.totalPages(),
        paged.currentPage(),
        paged.pageSize(),
        paged.hasNext(),
        paged.hasPrevious()
    );
}
```

---

## Multi-Datasource (Oracle + MSSQL)

```java
// Primary datasource (Oracle) — default, no qualifier needed
@ApplicationScoped
public class {Entity}EntityRepository implements PanacheRepository<{Entity}Entity, Long> {
    // uses default Oracle datasource
}

// Secondary datasource (MSSQL legacy) — named qualifier
@ApplicationScoped
@DataSource("mssql")
public class LegacyEntityRepository implements PanacheRepository<LegacyEntity, Long> {
    // uses "mssql" datasource defined in application.properties
}
```

```properties
# application.properties

# Primary — Oracle
quarkus.datasource.db-kind=oracle
quarkus.datasource.username=${DB_USER}
quarkus.datasource.password=${DB_PASS}
quarkus.datasource.jdbc.url=jdbc:oracle:thin:@${DB_HOST}:${DB_PORT}/${DB_SID}
quarkus.datasource.jdbc.max-size=20
quarkus.datasource.jdbc.min-size=2

# Named — MSSQL legacy
quarkus.datasource."mssql".db-kind=mssql
quarkus.datasource."mssql".username=${MSSQL_USER}
quarkus.datasource."mssql".password=${MSSQL_PASS}
quarkus.datasource."mssql".jdbc.url=jdbc:sqlserver://${MSSQL_HOST}:1433;databaseName=${MSSQL_DB};encrypt=true;

# Hibernate — validate schema at startup (catches migration mismatches)
quarkus.hibernate-orm.database.generation=validate
quarkus.hibernate-orm.log.sql=false        # true only for dev debugging
```

---

## Common JPA Pitfalls

| Pitfall | Correct Approach |
|---------|-----------------|
| `FetchType.EAGER` on collections | Use `FetchType.LAZY` always — load only what you need |
| N+1 query (loop + lazy load) | Use `JOIN FETCH` in JPQL or a batch fetch query |
| Bidirectional relation without `mappedBy` | Only one side owns the FK — use `mappedBy` on the other |
| `persist()` without a transaction | Wrap in `@Transactional` in the service layer |
| `merge()` instead of `persist()` on new entities | Check `entity.id == null` before choosing |
| `@Column(nullable = false)` without DB constraint | Flyway migration must match — both must be `NOT NULL` |
