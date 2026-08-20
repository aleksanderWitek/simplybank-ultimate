-- 1-to-1 links (kept as separate tables per your decision).
-- Single-column UNIQUEs enforce the 1-to-1; the old composite unique was redundant.
CREATE TABLE user_account_client (
                                     id              BIGINT       NOT NULL AUTO_INCREMENT,
                                     user_account_id BIGINT       NOT NULL,
                                     client_id       BIGINT       NOT NULL,
                                     create_date     DATETIME(6)  NOT NULL,
                                     delete_date     DATETIME(6),
                                     CONSTRAINT pk_user_account_client PRIMARY KEY (id),
                                     CONSTRAINT fk_uac_user_account FOREIGN KEY (user_account_id) REFERENCES user_account(id),
                                     CONSTRAINT fk_uac_client        FOREIGN KEY (client_id)       REFERENCES client(id),
                                     CONSTRAINT uk_uac_user_account  UNIQUE (user_account_id),
                                     CONSTRAINT uk_uac_client        UNIQUE (client_id)
);

CREATE TABLE user_account_employee (
                                       id              BIGINT       NOT NULL AUTO_INCREMENT,
                                       user_account_id BIGINT       NOT NULL,
                                       employee_id     BIGINT       NOT NULL,
                                       create_date     DATETIME(6)  NOT NULL,
                                       delete_date     DATETIME(6),
                                       CONSTRAINT pk_user_account_employee PRIMARY KEY (id),
                                       CONSTRAINT fk_uae_user_account FOREIGN KEY (user_account_id) REFERENCES user_account(id),
                                       CONSTRAINT fk_uae_employee      FOREIGN KEY (employee_id)     REFERENCES employee(id),
                                       CONSTRAINT uk_uae_user_account  UNIQUE (user_account_id),
                                       CONSTRAINT uk_uae_employee      UNIQUE (employee_id)
);