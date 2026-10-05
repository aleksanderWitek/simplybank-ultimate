# SimplyBank Ultimate — Final Plan (v2, Consolidated)

*Supersedes both earlier documents. All Review Council amendments folded in, plus the retry-storm defense raised by the project owner. This is the single document to work from.*

**Stack:** Spring Boot 4.0.x · Java 21 LTS · Spring Data JPA / Hibernate 7 (managed by Boot) · MySQL · Maven · Flyway · Testcontainers · GitHub Actions · Docker

---

## Design decisions (the "why" — read before coding)

These are the resolved decisions from both Councils. Each one is a thing you should be able to explain out loud.

**D1 — Spring Boot 4 + Java 21.** Boot 4 is the current recommended target for new projects; Java 21 is the LTS most employers run. Be aware most tutorials still target Boot 3.x — when an example doesn't compile, suspect the version gap first.

**D2 — JPA/Hibernate as primary persistence.** It's the industry default and the thing interviewers test. Old SimplyBank's JdbcTemplate code is the "before" picture — don't port it. `TransactionRepository.update()` is obsolete; it does not come over.

**D3 — Transfer concurrency: pure JPA optimistic locking.** One mechanism per operation. `@Version` on `Account`; load both accounts, mutate balances in Java, save; Hibernate's version check is the concurrency control; the "never negative" rule is a Java check inside the transaction (safe because the version check guarantees fresh data). The atomic-SQL alternative and the pessimistic alternative are **documented in the README, not implemented** — two mechanisms on one operation is broken, two on different operations is fine, and one mechanism plus a well-written README is correct for this project.

**D4 — Retry-storm defense (the owner's finding).** Optimistic locking guarantees progress (every conflict round has exactly one winner) but under deliberate contention it wastes work — an attacker can amplify cheap requests into expensive retry storms. Defense in depth, all in Phase 4:
- Bounded retries: `maxAttempts = 3`, then fail with HTTP 409.
- Exponential backoff **with jitter** between retries (no thundering herd).
- **Rate limiting on the transfer endpoint** (Bucket4j, per authenticated user) — promoted from "bonus" to **mandatory** by this finding.
- Fail-fast plumbing: `@Transactional(timeout = 5)`, bounded HikariCP pool, sensible `connectionTimeout`.
- Pessimistic locking documented as the hot-account fallback you'd switch to, with the reasoning.

**D5 — Money is `BigDecimal`.** Never `double`. Double-entry records (debit + credit pair) commit in the same transaction as the balance change.

**D6 — Flyway owns the schema.** Hibernate runs `ddl-auto=validate` only. Decide the soft-delete vs. unique-email indexing in `V1` (MySQL has no partial indexes → composite unique on `(email, deleted_marker)` or equivalent) — painful to retrofit later.

**D7 — Readability defaults.** DTOs as records with Bean Validation; record static factory methods for mapping (MapStruct optional, not default); one error shape via `@RestControllerAdvice` + Problem Details (RFC 9457); springdoc-openapi for live API docs. Optional cheap win: Boot 4's stable API versioning (`/api/v1/...`).

**D8 — CI from day one; CD last.** Minimal build-and-test workflow in Phase 0; the full pipeline (Testcontainers in CI, Docker, secrets, deploy) in Phase 7.

**D9 — Frontend.** Serve the vanilla JS frontend as static resources from Spring Boot itself — no CORS, one deployable.

---

## The Phases

### Phase 0 — Foundations + minimal CI (½–1 day)
1. New repo `simplybank-ultimate`. Old SimplyBank is frozen as the "before" picture.
2. start.spring.io: Boot 4.0.x, Java 21, Maven. Starters: Web, Data JPA, Security, Validation, MySQL Driver, Actuator. Add Flyway and Testcontainers dependencies.
3. `README.md` (template provided separately) and `CLAUDE.md`.
4. **Minimal CI now:** `.github/workflows/ci.yml` — checkout → setup Java 21 → `mvn verify`. Watch it go green on your first push. Every later phase is protected from here on.

*Learn:* what CI actually is, by watching it run on real commits from day one.

### Phase 1 — Flyway migrations (1 day)
1. Versioned SQL: `V1__create_users.sql`, `V2__create_accounts.sql`, `V3__create_transactions.sql` — including **indexes on lookup columns** (email, account number) and the **soft-delete/unique-email decision (D6)**.
2. `spring.jpa.hibernate.ddl-auto=validate`.

*Learn:* version-controlled schema, identical on laptop / CI / prod.

### Phase 2 — Entities & repositories (2–3 days)
1. `@Entity` classes: `User`, `Account`, `Transaction`; relationships; soft delete.
2. **`@Version` on `Account`** (this is D3's foundation).
3. Spring Data JPA repositories replace the old DAOs. Delete nothing from the old repo — just don't port `TransactionRepository.update()` or other JdbcTemplate code.
4. Hunt the **N+1 problem** on "user with accounts" — fix with `@EntityGraph` and note it in the README.

*Learn:* declarative persistence; spotting and fixing N+1.

### Phase 3 — Readable API layer (2 days)
Records-as-DTOs with validation; static factory mapping; Problem Details error handling; springdoc-openapi; `BigDecimal` everywhere money appears; optional API versioning. (All per D5/D7.)

*Learn:* the "easy to read for other programmers" toolkit.

### Phase 4 — The transfer (2 days) ← D3 + D4 live here
1. `@Transactional` transfer service: load both accounts, check sufficient funds in Java, mutate balances, write the debit+credit `Transaction` pair, save.
2. Spring Retry on `OptimisticLockException`: **max 3 attempts, exponential backoff with jitter**; on exhaustion → HTTP 409 with a Problem Details body.
3. **Bucket4j rate limit** on the transfer endpoint, keyed per authenticated user (e.g. 10/min).
4. Timeouts: transaction timeout, Hikari pool bounds.
5. README section: the locking trade-off, the retry-storm threat model, and when you'd switch a hot account to pessimistic.

*Learn:* the most interview-dense code in the project — concurrency, correctness, and its abuse case.

### Phase 4½ — Security + RBAC features (2–3 days) → 🏁 DEMO-READY MILESTONE
1. Spring Security config ported to the current generation (lambda DSL); BCrypt stays.
2. **JWT access + refresh token flow** (short-lived access, longer refresh).
3. RBAC (CLIENT / EMPLOYEE / ADMIN) enforced with method security (`@PreAuthorize`).
4. **The adopted TODOs become the proof of RBAC:**
   - Per-role profile page (show own details).
   - Add client (EMPLOYEE + ADMIN).
   - Add employee (ADMIN only).
   - Update password.
   - Login page: login + password fields only — no register, no forgot-password link.
5. Least-privilege MySQL user (not root); all secrets from env/config, never code.
6. Bonus only: Argon2, broader rate limiting.

**After this phase the project is interview-worthy even if nothing else ships. Everything beyond is improvement, not rescue.**

### Phase 5 — Performance polish (1 day)
Virtual threads on (`spring.threads.virtual.enabled=true`); Hikari pool tuned and understood; Actuator metrics so claims are measured; optional Caffeine cache for read-only data (never balances).

### Phase 6 — Tests that can't lie (2 days)
1. Unit tests (Mockito) for service logic.
2. Integration tests on **Testcontainers MySQL** (matches your real-MySQL-not-H2 rule; identical on laptop and CI).
3. **Hardened concurrency test (Amendment 5):** ~50 threads hammering two accounts; assert *invariants* — total money unchanged, every transfer's debit+credit sums to zero; plus one variant with **retry disabled** to prove conflicts are detected (`OptimisticLockException` observed), separate from the retry that handles them.

### Phase 7 — Full pipeline & deploy (2–3 days)
1. Multi-stage Dockerfile; Docker Compose (app + MySQL) for one-command local run.
2. Extend CI: Testcontainers integration tests in the runner; Docker image build.
3. GitHub Secrets for anything sensitive.
4. Dependabot on.
5. Optional CD: pick a host **at that time** (free tiers shift; managed MySQL is scarcer than Postgres — don't switch DBs just for a tier). Live URL on the CV if it works out cheaply.
6. Frontend served as Spring Boot static resources (D9).

---

## Timeline & rules

| Milestone | Cumulative effort |
|---|---|
| CI green on first commit | day 1 |
| Schema + entities working | ~week 1–2 |
| Transfer with full defense stack | ~week 2–3 |
| 🏁 Demo-ready (post-4½) | ~week 3–4 |
| Tested + pipelined + deployed | ~week 5–7 |

Rules: phases in order; commit after each; the demo-ready milestone is sacred; every decision D1–D9 gets a sentence in the README — the reasoning is what gets you hired.
