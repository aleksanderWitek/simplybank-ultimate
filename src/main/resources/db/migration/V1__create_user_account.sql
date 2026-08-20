-- Authentication accounts. Soft-deleted via delete_date (nullable timestamp).
-- active_login: generated column enabling login reuse after soft-delete (D6).
CREATE TABLE user_account (
                              id           BIGINT       NOT NULL AUTO_INCREMENT,
                              login        VARCHAR(20)  NOT NULL,
                              password     VARCHAR(60)  NOT NULL,           -- BCrypt hash length
                              role         VARCHAR(50)  NOT NULL,           -- mapped to a Java enum (STRING)
                              create_date  DATETIME(6)  NOT NULL,
                              modify_date  DATETIME(6),
                              delete_date  DATETIME(6),
                              active_login VARCHAR(20) GENERATED ALWAYS AS (IF(delete_date IS NULL, login, NULL)) VIRTUAL,
                              CONSTRAINT pk_user_account PRIMARY KEY (id),
                              CONSTRAINT uk_user_account_active_login UNIQUE (active_login)
);