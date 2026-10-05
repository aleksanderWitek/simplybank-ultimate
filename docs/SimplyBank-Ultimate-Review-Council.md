# SimplyBank Ultimate — The Review Council

*An independent audit of the original Council plan. New members, no loyalty to the first Council's decisions. Their job: find what's wrong, contradictory, missing, or unrealistic — and fix it.*

---

## Who is on the Review Council

- **Renata — The Red Team Lead (Staff Engineer).** Reads plans looking for internal contradictions and things that won't survive contact with reality.
- **Tomás — QA & Correctness Engineer.** Doesn't trust any test until he's seen how it could pass while the code is broken.
- **Priya — Hiring Manager.** Has interviewed dozens of self-taught Java candidates. Judges everything by one question: *"does this make Alex more hireable, faster?"*
- **Conor — Junior Developer.** The "easy to read for other programmers" requirement made flesh. If Conor can't follow it, the plan failed its own brief.
- **Eva — Delivery Lead.** Owns scope and timeline. Allergic to plans that assume infinite evenings.

**The verdict up front:** the original plan is *fundamentally sound* — right stack, right priorities, right CI/CD mental model. But the Review Council found **one real technical contradiction, one missing phase, one orphaned piece of your existing work, and several realism problems.** Approved **with amendments**, listed at the end.

---

## Finding 1 — 🔴 The locking design contradicts itself (the big one)

**Renata:** Phase 4 of the original plan tells you to do *both* of these for the transfer:

1. Optimistic locking via `@Version` on the `Account` entity, with retry on `OptimisticLockException`, **and**
2. An atomic native SQL update: `UPDATE account SET balance = balance - :amt WHERE id = :id AND balance >= :amt`.

These are **two different concurrency mechanisms, and combined naively they fight each other.** Here's why, in plain terms:

- The `@Version` mechanism only works when **Hibernate itself** performs the update — it reads the entity, you change the balance *in Java*, and on save Hibernate checks "is the version still what I read?" and bumps it.
- The native SQL update **goes around Hibernate's back.** The database changes, but the entity in Hibernate's session is now *stale*, and the `version` column was never incremented — so the optimistic lock protected nothing. Worse, a later save of that stale entity could overwrite the balance with old data.

The original plan presents these as one harmonious design. They aren't. **You must pick a primary mechanism.**

**Tomás:** And this isn't pedantry — this exact confusion is how real money bugs happen. Whichever you pick, the *test* has to be designed to catch the failure mode of that choice (see Finding 5).

> **AMENDMENT 1 — Pick one coherent transfer design:**
>
> **Option A (recommended): pure JPA optimistic.** Load both accounts as entities, change balances in Java, `save()`. Hibernate's `@Version` check is the concurrency control. On `OptimisticLockException`, retry the whole transfer. The "never go negative" rule becomes a Java check *inside* the transaction (safe, because the version check guarantees you acted on fresh data).
> *Why recommended:* it's the design that actually teaches JPA — which is the point of this project — and it's fully expressible in interview language.
>
> **Option B: atomic SQL.** The `UPDATE ... WHERE balance >= :amt` statement *is* the concurrency control (check the affected-row count; 0 rows = insufficient funds). Then `@Version` on balance changes is redundant — drop it or bump it manually inside the same statement, and **evict/refresh** the entity afterwards so the session isn't stale.
>
> Implement **A** as the primary. Document **B** in the README as the alternative you understood and consciously didn't need. The original plan's mistake was telling you to do both at once.

---

## Finding 2 — 🔴 Security was debated… and then never scheduled

**Priya:** This one made me laugh. The first Council had a whole debate (Debate 5) resolving JWT access + refresh tokens, externalized secrets, least-privilege DB user, Problem Details, Dependabot… and then I read Phases 0 through 7 and **Spring Security and JWT appear in no phase at all.** Validation snuck into Phase 3 and secrets into Phase 7, but the actual authentication system — the refresh-token flow that the Council itself called "the single biggest *you actually understand auth* upgrade" — was never given a home. A plan item without a phase is a wish.

**Conor:** Also, as the person who'd have to read this code: porting Spring Security config from old SimplyBank into Spring Boot 4 / Spring Security's current generation isn't copy-paste — config style and some APIs moved. That deserves dedicated time, not a side quest.

> **AMENDMENT 2 — Add an explicit security phase.** Insert **Phase 4½ — Security (2–3 days)**: port and modernize the Spring Security config, implement the **access + refresh token** flow, keep BCrypt, wire the RBAC roles (CLIENT / EMPLOYEE / ADMIN) into method-level security (`@PreAuthorize`), and confirm the least-privilege MySQL user. Rate limiting and Argon2 remain bonus, as before.

---

## Finding 3 — 🟠 Your in-flight work was silently orphaned

**Eva:** The original plan says "create a brand-new repo, freeze the old one" — fine — but it never says what happens to the **unfinished features sitting on your current `virtualization-security` branch**: the per-role profile page, add-client (employee+admin), add-employee (admin-only), password update, and the stripped-down login page (login + password only, no register/forgot links). Those just… vanish from the plan. That's how work gets lost.

**Priya:** And they shouldn't vanish, because they're *good*. Per-role pages and admin-only creation flows are exactly the features that demonstrate RBAC actually working — which is far more convincing in an interview than RBAC existing only in a config file.

> **AMENDMENT 3 — Adopt the orphaned TODOs into Ultimate's scope.** They become the **feature checklist for Phase 4½ and beyond**: the profile/add-client/add-employee/password-update features are how you *prove* the RBAC system, and the minimal login page is the front door. Don't finish them on the old branch — freeze old SimplyBank as-is (it's your "before" picture) and build these features fresh in Ultimate.

---

## Finding 4 — 🟠 CI was scheduled last, which defeats half its purpose

**Eva:** The original plan puts all of CI/CD in Phase 7, "do it last, once the app works." I understand Ben's instinct — don't overwhelm the learner — but it's backwards. The entire *point* of CI is that it watches your back **while you build**. If it only arrives at the end, Phases 1–6 get zero protection from it, and you learn CI under time pressure instead of gradually.

**Renata:** And a minimal CI workflow is genuinely tiny — checkout, set up Java, `mvn verify`. Fifteen lines of YAML.

> **AMENDMENT 4 — Split CI from CD.**
> - **Phase 0 now includes minimal CI:** a GitHub Actions workflow that builds and runs unit tests on every push. You'll watch it go green/red from day one, which is how the concept actually sinks in.
> - **Phase 7 keeps the advanced pipeline:** Testcontainers integration tests in CI, Docker image build, secrets, and optional deployment.
> This costs nothing and means every commit from week one is verified.

---

## Finding 5 — 🟠 The concurrency test, as described, can lie to you

**Tomás:** The original plan's Phase 6 says: "fire two transfers at one account simultaneously and assert the balance is still correct." Here's the trap: **with retry enabled, that test can pass even when your locking is broken**, because the retry loop can paper over a race by sheer luck of timing. A green test that can't fail is worse than no test.

> **AMENDMENT 5 — Strengthen the test design:**
> 1. Use **many** concurrent transfers (e.g. 50 threads hammering two accounts), not two.
> 2. Assert the **invariant**, not just one balance: total money across all accounts is unchanged, and every transfer produced its **matching debit + credit pair** (double-entry sums to zero).
> 3. Run one variant **with retry disabled** to prove conflicts are actually *detected* (you should see `OptimisticLockException`s) — that's your evidence the lock mechanism works, separate from the retry that handles it.

---

## Finding 6 — 🟡 Smaller catches (quick fire)

**Renata — soft delete vs. unique email.** You keep soft deletes (good), but a plain `UNIQUE` index on `email` means a *deleted* user's email blocks re-registration forever. MySQL has no partial indexes, so the standard trick is a composite unique key on `(email, deleted_marker)` where the marker is `NULL`/timestamp-based. Small thing — but it's a Flyway `V1` decision, painful to retrofit. Decide it in Phase 1.

**Conor — MapStruct demoted.** The plan made MapStruct sound standard. For an app this size, a **static factory method on the record** (`TransferResponse.from(entity)`) is simpler, has zero annotation-processor setup, and is *more* readable for someone like me. Keep MapStruct as optional, not mandatory.

**Conor — learning-resource reality.** Spring Boot 4 is the right call, but be warned: most tutorials, Stack Overflow answers, and your Udemy courses target Boot 3.x. At the application level the differences are modest, but when an example doesn't compile, suspect the version gap first. Budget a little friction for this.

**Priya — one cheap win missed.** Spring Boot 4's headline feature is **stable API versioning for HTTP endpoints**. It's nearly free to adopt (`/api/v1/...` done the framework's way) and gives you a current-framework talking point almost nobody else will have. Optional, recommended.

**Eva — frontend went unmentioned.** Old SimplyBank has a vanilla JS frontend. The plan never says how it connects to Ultimate. Decision needed: either serve the static files **from Spring Boot itself** (simplest — no CORS at all) or host separately and configure CORS properly. Recommend the first.

**Eva — deployment claims need verification.** The plan names Railway / Render / Fly.io with managed MySQL as if it's a solved one-liner. Free-tier offerings change constantly, and managed **MySQL** specifically is thinner on free tiers than Postgres. Don't pre-commit — when you reach Phase 7, check what's actually free *that week*. (And no, don't switch the whole project to Postgres just for a free tier — consistency with your local MySQL and Testcontainers setup is worth more.)

**Eva — timeline honesty.** "4–6 weeks of evenings" assumes evenings exist. You have a full-time job, an active job hunt, and a life. The fix isn't a longer estimate — it's a **demo-ready milestone**: after Phase 4½ (entities + transfer + security + the RBAC features), the project is already interview-worthy *even if you never reach Phase 7*. Mark that milestone explicitly and you can never be caught with "it's half-finished."

---

## The Amended Plan (delta view — everything else stands)

| Phase | Change |
|-------|--------|
| 0 | **+ minimal CI** (build + unit tests on push) — *Amendment 4* |
| 1 | **+ decide soft-delete/unique-email indexing** in `V1` migrations — *Finding 6* |
| 3 | MapStruct **demoted to optional**; record factory methods default. **+ optional API versioning** — *Finding 6* |
| 4 | **Locking redesigned**: Option A (pure JPA optimistic) primary, Option B (atomic SQL) documented alternative — *Amendment 1* |
| **4½ (NEW)** | **Security phase**: Spring Security port, JWT access + refresh, RBAC enforcement, **+ the adopted TODOs** (profile pages, add-client, add-employee, password update, minimal login page) — *Amendments 2 & 3*. **🏁 Demo-ready milestone after this phase.** |
| 5 | Unchanged |
| 6 | **Concurrency test strengthened**: invariants, many threads, retry-off variant — *Amendment 5* |
| 7 | CI parts already done; remains **Docker, Testcontainers-in-CI, secrets, optional deploy** (verify host free tiers at the time). **+ frontend serving decision** — *Amendment 4, Finding 6* |

Revised effort: roughly **+3 days** versus the original (the security phase is genuinely new work; everything else is reshuffling). The demo-ready milestone lands around week 3–4.

---

## Closing statements

**Priya (Hiring Manager):** With the amendments, this is a strong portfolio project. The things that will actually get Alex interviews, in order: the live CI badge on the repo from week one, the README explaining the locking decision *and the contradiction you caught in your own first design*, and working RBAC you can click through. Candidates who can say "my first plan had a flaw — here's how I found it and what I changed" interview better than candidates who claim their plan was perfect.

**Renata (Red Team):** The original Council did good work — the CI/CD mental model correction alone was worth the meeting. But "use @Version *and* atomic SQL" is exactly the kind of plausible-sounding blend that two smart suggestions make when nobody checks whether they compose. They don't. Now it's fixed.

**Eva (Delivery):** One rule above all: **the demo-ready milestone after Phase 4½ is sacred.** Everything before it is mandatory; everything after it improves an already-showable project. Plan for interruptions, because they're coming.

**Verdict: APPROVED WITH AMENDMENTS.** Proceed.
