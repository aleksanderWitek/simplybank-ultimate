-- Immutable ledger: create_date only, never modified or deleted.
-- from/to are nullable: DEPOSIT has no 'from', WITHDRAWAL has no 'to'.
CREATE TABLE bank_transaction (
                                  id                   BIGINT        NOT NULL AUTO_INCREMENT,
                                  transaction_type     VARCHAR(20)   NOT NULL,   -- was ENUM; now VARCHAR + Java enum
                                  currency             VARCHAR(3)    NOT NULL,
                                  amount               DECIMAL(14,2) NOT NULL,
                                  bank_account_id_from BIGINT,
                                  bank_account_id_to   BIGINT,
                                  description          VARCHAR(255),
                                  create_date          DATETIME(6)   NOT NULL,
                                  CONSTRAINT pk_bank_transaction PRIMARY KEY (id),
                                  CONSTRAINT fk_bank_transaction_from FOREIGN KEY (bank_account_id_from) REFERENCES bank_account(id),
                                  CONSTRAINT fk_bank_transaction_to   FOREIGN KEY (bank_account_id_to)   REFERENCES bank_account(id)
);