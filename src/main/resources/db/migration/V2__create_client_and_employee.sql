CREATE TABLE client (
                        id                    BIGINT       NOT NULL AUTO_INCREMENT,
                        first_name            VARCHAR(30)  NOT NULL,
                        last_name             VARCHAR(30)  NOT NULL,
                        city                  VARCHAR(30)  NOT NULL,
                        street                VARCHAR(30)  NOT NULL,
                        house_number          VARCHAR(10)  NOT NULL,
                        identification_number VARCHAR(15)  NOT NULL,
                        create_date           DATETIME(6)  NOT NULL,
                        modify_date           DATETIME(6),
                        delete_date           DATETIME(6),
                        CONSTRAINT pk_client PRIMARY KEY (id),
                        INDEX idx_client_identification_number (identification_number)
);

CREATE TABLE employee (
                          id          BIGINT       NOT NULL AUTO_INCREMENT,
                          first_name  VARCHAR(30)  NOT NULL,
                          last_name   VARCHAR(30)  NOT NULL,
                          create_date DATETIME(6)  NOT NULL,
                          modify_date DATETIME(6),
                          delete_date DATETIME(6),
                          CONSTRAINT pk_employee PRIMARY KEY (id)
);