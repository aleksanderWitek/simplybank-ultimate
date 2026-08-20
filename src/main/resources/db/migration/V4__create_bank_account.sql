CREATE TABLE bank_account (
                              id             BIGINT        NOT NULL AUTO_INCREMENT,
                              account_number VARCHAR(15)   NOT NULL,
                              account_type   VARCHAR(20)   NOT NULL,
                              currency       VARCHAR(3)    NOT NULL,           -- ISO 4217 (EUR, USD...)
                              balance        DECIMAL(14,2) NOT NULL,
                              version        BIGINT        NOT NULL DEFAULT 0, -- optimistic locking (D3)
                              create_date    DATETIME(6)   NOT NULL,
                              modify_date    DATETIME(6),
                              delete_date    DATETIME(6),
                              CONSTRAINT pk_bank_account PRIMARY KEY (id),
                              CONSTRAINT uk_bank_account_number UNIQUE (account_number)
);

-- Many-to-many: a joint account can have several owners (this link stays).
CREATE TABLE bank_account_client (
                                     id              BIGINT       NOT NULL AUTO_INCREMENT,
                                     bank_account_id BIGINT       NOT NULL,
                                     client_id       BIGINT       NOT NULL,
                                     create_date     DATETIME(6)  NOT NULL,
                                     delete_date     DATETIME(6),
                                     CONSTRAINT pk_bank_account_client PRIMARY KEY (id),
                                     CONSTRAINT fk_bac_bank_account FOREIGN KEY (bank_account_id) REFERENCES bank_account(id),
                                     CONSTRAINT fk_bac_client        FOREIGN KEY (client_id)       REFERENCES client(id),
                                     CONSTRAINT uk_bac_account_client UNIQUE (bank_account_id, client_id)
);