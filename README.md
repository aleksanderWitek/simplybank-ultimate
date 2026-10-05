# SimplyBank Ultimate

A banking REST API built to modern Java standards — the ground-up successor to [SimplyBank](https://github.com/aleksanderWitek/simplybank), rebuilt to learn and demonstrate current industry practice: Spring Boot 4, JPA/Hibernate, optimistic concurrency with abuse-resistant retry handling, JWT auth with refresh tokens, Testcontainers, and a full CI/CD pipeline.

![CI](https://github.com/aleksanderWitek/simplybank-ultimate/actions/workflows/ci.yml/badge.svg)

## Stack

| Layer | Choice |
|---|---|
| Language / Runtime | Java 21 (LTS), virtual threads enabled |
| Framework | Spring Boot 4.0.x (Spring Framework 7) |
| Persistence | Spring Data JPA / Hibernate ORM 7, MySQL 8 |
| Schema | Flyway versioned migrations (Hibernate in `validate` mode) |
| Security | Spring Security, JWT access + refresh tokens, BCrypt, RBAC |
| API | REST, DTOs as Java records, Bean Validation, Problem Details (RFC 9457), OpenAPI via springdoc |
| Testing | JUnit 5, Mockito (unit), Testcontainers MySQL (integration), concurrency invariant tests |
| Delivery | GitHub Actions CI, multi-stage Docker build, Docker Compose for local dev |

## Why these choices (design decisions)

This project documents its reasoning deliberately — the trade-offs matter as much as the code.

### Concurrency: optimistic locking, with eyes open
Money transfers use **JPA optimistic locking** (`@Version` on `Account`) inside a single `@Transactional` boundary. One mechanism per operation — the native-SQL atomic update was considered and rejected *in combination* with `@Version`, because a native update bypasses Hibernate: the version never increments and the session goes stale. (Atomic SQL *alone* is a valid alternative design; mixing the two is not.)

**Known failure mode — retry storms:** optimistic locking guarantees progress (each conflict round has exactly one winner) but wastes work under heavy contention, which an attacker can exploit by flooding one account with transfers. Defenses, layered:
1. Retries bounded at **3 attempts** with **exponential backoff + jitter**; exhaustion → `409 Conflict`.
2. **Per-user rate limiting** on the transfer endpoint (Bucket4j).
3. Fail-fast timeouts (transaction timeout, bounded HikariCP pool) so overload sheds quickly instead of queueing to death.

**When I'd switch strategies:** for a known-hot account (e.g. a merchant receiving thousands of payments), pessimistic locking (`SELECT … FOR UPDATE`) wins — requests queue at the row instead of doing throwaway work. The right production pattern routes per *account*, never mixes mechanisms on one operation. Not implemented here by design: for this project's scale, optimistic + bounded retry is correct, and the routing machinery would be over-engineering.

### Correctness
- Balances are **`BigDecimal`** — floating point never touches money.
- Every transfer writes a **double-entry pair** (debit + credit) in the same transaction as the balance change: all-or-nothing.
- Insufficient-funds is checked inside the transaction; the version check guarantees the data read was fresh.
- The concurrency test asserts **invariants** (total money conserved; entries sum to zero) under ~50 parallel transfers, plus a retry-disabled variant proving conflicts are *detected*, not just papered over.

### Schema
Flyway owns the schema; Hibernate only validates. Soft deletes are used, so the email uniqueness constraint is composite (MySQL has no partial indexes) to allow re-registration after deletion.

### Security
- JWT **access + refresh** token flow; short-lived access tokens.
- RBAC: `CLIENT` / `EMPLOYEE` / `ADMIN`, enforced with method-level security. Employee/admin-only flows (add client, add employee) demonstrate it end to end.
- BCrypt password hashing; least-privilege MySQL user; all secrets via environment variables — nothing sensitive in the repo.
- Dependabot enabled for dependency vulnerability alerts.

## Running locally

Prerequisites: Docker.

```bash
git clone https://github.com/aleksanderWitek/simplybank-ultimate.git
cd simplybank-ultimate
docker compose up
```

App: `http://localhost:8080` · API docs: `http://localhost:8080/swagger-ui.html`

Without Docker: Java 21 + a local MySQL, then

```bash
./mvnw spring-boot:run
```

Configuration via environment variables (see `.env.example`): `DB_URL`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`.

## Testing

```bash
./mvnw test                    # unit tests (no database needed)
./mvnw verify                  # + integration tests (Testcontainers boots MySQL automatically)
```

Integration tests run against a **real MySQL** in a disposable container — never H2 — so test behavior matches production behavior, identically on a laptop and in CI.

## CI/CD

Every push and pull request triggers GitHub Actions: build → unit tests → integration tests (Testcontainers inside the runner) → Docker image build. Secrets are injected from GitHub Secrets; the pipeline never sees credentials in code.

## API overview

| Endpoint | Method | Role | Notes |
|---|---|---|---|
| `/api/v1/auth/login` | POST | public | returns access + refresh tokens |
| `/api/v1/auth/refresh` | POST | public | exchanges refresh token |
| `/api/v1/profile` | GET | any authenticated | own details, shaped per role |
| `/api/v1/accounts` | POST | CLIENT+ | open account |
| `/api/v1/transfers` | POST | CLIENT+ | rate-limited; 409 on contention exhaustion |
| `/api/v1/users/clients` | POST | EMPLOYEE, ADMIN | create client |
| `/api/v1/users/employees` | POST | ADMIN | create employee |
| `/api/v1/users/password` | PUT | any authenticated | change own password |

Full, live documentation at `/swagger-ui.html`.

## Project history

The original [SimplyBank](https://github.com/aleksanderWitek/simplybank) (Spring Boot 3, JdbcTemplate, pessimistic locking) is preserved unchanged as the before-picture. This rebuild was planned as a deliberate modernization exercise; the planning process itself surfaced and fixed a design contradiction (mixing `@Version` with native-SQL updates) before any code was written — documented above because catching your own design flaws early is the point of planning.

## License

MIT
