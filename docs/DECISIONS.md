# Decision log

Append-only. One entry per decision that a future reader might otherwise question.
Git records *what* changed; this records *why*. Newest at the bottom.

Format: `YYYY-MM-DD — Decision. Reason. (alternatives rejected)`

---

2026-08-20 — New repo `simplybank-ultimate` instead of patching SimplyBank. Old project frozen as the "before" picture for comparison.

2026-08-20 — Spring Boot 4.0.x on Java 21 LTS. Boot 4 is current for new projects; Java 21 is what most employers run. (Java 25 LTS viable but less common in industry.)

2026-08-20 — CI added in Phase 0, not Phase 7. A pipeline that arrives at the end protects nothing during development.

2026-08-20 — `mvnw` committed with the executable bit (`100755`). Windows doesn't track it, so the Linux CI runner refused to execute it (exit 126).

2026-08-20 — Transfer concurrency: pure JPA optimistic locking (D3). The original plan called for `@Version` *and* atomic native SQL together; the review found these conflict — native SQL bypasses Hibernate, so the version never increments and the session goes stale. One mechanism per operation.

2026-08-20 — Retry-storm defenses promoted to mandatory (D4) after identifying that flooding one account with transfers amplifies cheap requests into expensive retry loops. Rate limiting moved from "bonus" to required on the transfer endpoint.

2026-08-20 — Logins reusable after soft-delete (D6), via an `active_login` generated column that is NULL for deleted rows. MySQL has no partial indexes; NULLs are distinct in a unique index.

2026-08-20 — Kept `user_account_client` / `user_account_employee` as separate 1-to-1 link tables rather than collapsing to direct FKs. (Owner's preference; direct FK is the more common modelling choice.)

2026-08-20 — Schema modernized from the original: BIGINT ids, `DATETIME(6)`, `ENUM` → `VARCHAR` + Java enum, `transaction` → `bank_transaction`, `number` → `account_number` (reserved words), `version` column added to `bank_account`.

2026-08-20 — Explicit indexes kept minimal: InnoDB auto-indexes foreign-key columns, so only `account_number` (unique) and `identification_number` (lookup) needed adding by hand.

2026-08-20 — `spring.jpa.open-in-view=false`. Default `true` lets queries fire after the service layer returns, hiding N+1 problems.
