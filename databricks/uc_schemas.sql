CREATE SCHEMA IF NOT EXISTS main.silver COMMENT 'Conformed LOS / PPE / warehouse / blotter feeds';
CREATE SCHEMA IF NOT EXISTS main.gold_cm COMMENT 'Capital markets star — facts and dimensions';
CREATE SCHEMA IF NOT EXISTS main.ref_cm COMMENT 'PT grid, policy bands, duration map';
CREATE SCHEMA IF NOT EXISTS main.gold COMMENT 'Compatibility views over gold_cm';
