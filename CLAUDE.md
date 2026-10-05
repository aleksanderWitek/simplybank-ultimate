# CLAUDE.md — SimplyBank Ultimate

Read this file and `docs/` before starting work.

## What this project is

A banking REST API, rebuilt from scratch to modern standards as a portfolio piece for Java developer roles.
**Alex is using this project to learn** — explain your reasoning before making changes, don't just generate code.

**Stack:** Spring Boot 4.0.x · Java 21 LTS · Spring Data JPA / Hibernate 7 · MySQL 8 · Maven · Flyway · Testcontainers · GitHub Actions

---

## Current status

**Phases 0–1 complete.**
- Project scaffolded, CI green on every push (`.github/workflows/ci.yml`).
- Flyway migrations `V1`–`V5` applied and verified locally + in CI.
- `flyway_schema_history` shows 5 successful migrations.

**Next: Phase 2 — JPA entities** mapping the existing Flyway schema.

⚠️ `spring.jpa.hibernate.ddl-auto=validate` is active. From the first `@Entity` onward, startup fails on any mismatch between Java and the schema. That is intended behaviour — read the error, it names the column.

---

## Key decisions (full reasoning in `docs/`)

| ID | Decision |
|----|----------|
| D3 | Transfer concurrency = **pure JPA optimistic locking** (`@Version` on `bank_account`). Never combine with native-SQL balance updates — they bypass Hibernate and void the version check. Atomic-SQL and pessimistic alternatives are documented only. |
| D4 | **Retry-storm defense** (Phase 4): bounded retries (3) + jittered backoff + per-user rate limiting (Bucket4j) on the transfer endpoint + fail-fast timeouts. |
| D5 | Money is **`BigDecimal`**, never `double`. Transfers write a double-entry debit+credit pair in the same transaction. |
| D6 | Logins are **reusable after soft-delete**, enforced by the `active_login` generated column in `V1` (MySQL has no partial indexes). |
| D7 | Readability: DTOs as records + Bean Validation; record factory methods for mapping (not MapStruct); Problem Details (RFC 9457) for errors; springdoc-openapi. |
| — | 1-to-1 link tables (`user_account_client`, `user_account_employee`) kept deliberately, not collapsed to direct FKs. |
| — | Soft delete = nullable `delete_date` timestamp; `bank_transaction` is an **immutable ledger** (create only). |

---

## Project structure

Describes packages and their purpose — kept coarse on purpose so it stays accurate.

```
src/main/java/com/simplybank/simplybank_ultimate/
  (Phase 2+ — package layout to be decided when entities are written)

src/main/resources/
  db/migration/         Flyway migrations, V1–V5. Append-only: never edit an applied file, add V6+.
  application.properties  Config with ${ENV_VAR} placeholders — no literal secrets, ever.

src/test/java/          Unit tests (Mockito) + integration tests (Testcontainers MySQL, never H2).

.github/workflows/ci.yml  Build + test on every push and PR.
docs/                     Plan and review-council documents (the D-decisions above).
.env.example              Documents which env vars are required. Read by nothing — it's a note for humans.
```

**Secrets:** real values come from the IntelliJ run config (local), Docker Compose `.env` (Phase 7), and GitHub Secrets (CI). The variable *names* are the contract: `DB_URL`, `DB_USER`, `DB_PASSWORD`.

---

**How to use the structure map above:** treat it as the entry point when locating code — find the right package first, then search within it, rather than scanning the whole tree. It is deliberately coarse (packages and their purpose, not a file listing) so it stays accurate as files come and go. When a new package is introduced or a package's purpose changes, add or amend one line here in the same change.

---

## Global preferences

Personal preferences that apply across all of Alex's projects live in `~/.claude/CLAUDE.md`
(Windows: `C:\Users\aleks\.claude\CLAUDE.md`) and are loaded automatically alongside this file.
That file holds durable habits and standards; this file holds facts about *this* project.
When adding a new instruction, put it in whichever of the two it genuinely belongs to — don't duplicate it in both.

---

## Working agreement

- Explain the reasoning before changing code; Alex is learning, not just shipping.
- Follow the phase order in `docs/` — don't jump ahead.
- Never invent a new concurrency mechanism for transfers; D3 is settled.
- Never put a secret in a committed file.
- Migrations are append-only.
- After a meaningful decision (not every commit), append one line to `docs/DECISIONS.md`.
- If this file's **Current status** or **Project structure** becomes wrong, update it as part of the same change.
