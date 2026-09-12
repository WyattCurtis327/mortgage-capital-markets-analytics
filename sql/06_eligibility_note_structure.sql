-- =============================================================================
-- Schema gaps 1 and 2
--   1. Loan / collateral / borrower attributes for LLPA and eligibility replay
--   2. ARM / IO / buydown note structure
-- Additive. Run after 05_gold_star_ddl.sql. Databricks SQL / Delta.
-- =============================================================================

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_note_structure (
  note_structure_key INT NOT NULL,
  note_structure_code STRING NOT NULL COMMENT 'FIX_30 | ARM_5_6_SOFR | FIX_30_IO10 | FIX_30_BD21',
  amortization_type STRING NOT NULL COMMENT 'fixed|arm',
  arm_index STRING COMMENT 'sofr|cmt1y|libor_legacy',
  arm_margin_bps DECIMAL(8,2),
  arm_initial_period_mo INT,
  arm_reset_period_mo INT,
  io_flag BOOLEAN NOT NULL,
  io_term_months INT,
  buydown_type STRING COMMENT 'none|2_1|1_0|3_2_1',
  buydown_term_months INT,
  prepay_penalty_flag BOOLEAN NOT NULL,
  prepay_term_months INT,
  balloon_flag BOOLEAN NOT NULL,
  balloon_term_months INT
) USING DELTA
COMMENT 'Actual note shape used for duration, TBA coupon, and LLPAs';

ALTER TABLE main.gold_cm.dim_product ADD COLUMNS (
  default_note_structure_key INT COMMENT 'FK dim_note_structure',
  qualifying_rate_method STRING COMMENT 'note|arm_fully_indexed|buydown_note'
);

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_property_type (
  property_type_key INT NOT NULL,
  property_type_code STRING NOT NULL COMMENT 'sfr|pud|condo|coop|2_4_unit|manufactured|attached',
  units_typical INT,
  project_flag BOOLEAN
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_occupancy (
  occupancy_key INT NOT NULL,
  occupancy_code STRING NOT NULL COMMENT 'primary|second|investment'
) USING DELTA;

ALTER TABLE main.gold_cm.dim_loan ADD COLUMNS (
  occupancy_key INT,
  property_type_key INT,
  note_structure_key INT,
  units INT,
  fico INT,
  ltv DECIMAL(8,4),
  cltv DECIMAL(8,4),
  dti DECIMAL(8,4),
  high_balance_flag BOOLEAN,
  jumbo_flag BOOLEAN,
  mi_flag BOOLEAN,
  first_time_homebuyer BOOLEAN,
  manufactured_flag BOOLEAN,
  condo_project_type STRING,
  mers_min STRING,
  agency_loan_number STRING,
  los_loan_number STRING
);

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_loan_eligibility (
  loan_id STRING NOT NULL,
  lock_id STRING,
  event_type STRING NOT NULL COMMENT 'lock|fund|sale',
  as_of_ts TIMESTAMP NOT NULL,
  as_of_date DATE NOT NULL,
  channel_key INT,
  product_key INT,
  purpose_key INT,
  occupancy_key INT,
  property_type_key INT,
  note_structure_key INT,
  coupon_bucket_key INT,
  units INT,
  state STRING,
  fico INT,
  ltv DECIMAL(8,4),
  cltv DECIMAL(8,4),
  dti DECIMAL(8,4),
  note_rate DECIMAL(8,5),
  qualifying_rate DECIMAL(8,5),
  original_upb DECIMAL(18,2),
  cashout_amount DECIMAL(18,2),
  subordinate_upb DECIMAL(18,2),
  high_balance_flag BOOLEAN,
  jumbo_flag BOOLEAN,
  mi_flag BOOLEAN,
  mi_coverage_pct DECIMAL(8,4),
  first_time_homebuyer BOOLEAN,
  manufactured_flag BOOLEAN,
  condo_project_type STRING,
  self_employed_flag BOOLEAN,
  reserves_months DECIMAL(8,2),
  llpa_pts DECIMAL(12,6),
  gfee_bps DECIMAL(8,2),
  src_system STRING
) USING DELTA
PARTITIONED BY (as_of_date)
COMMENT 'Decision-time credit/collateral for LLPA and best-ex replay';

ALTER TABLE main.gold_cm.fact_lock_snapshot_daily ADD COLUMNS (
  note_structure_key INT,
  occupancy_key INT,
  property_type_key INT,
  hedge_coupon_bucket_key INT COMMENT 'TBA coupon used to hedge; may differ from note coupon',
  fico INT,
  ltv DECIMAL(8,4),
  cltv DECIMAL(8,4),
  dti DECIMAL(8,4),
  units INT,
  high_balance_flag BOOLEAN,
  jumbo_flag BOOLEAN,
  mi_flag BOOLEAN
);

ALTER TABLE main.gold_cm.fact_loan_fund ADD COLUMNS (
  note_structure_key INT,
  occupancy_key INT,
  property_type_key INT,
  fico INT,
  ltv DECIMAL(8,4),
  cltv DECIMAL(8,4),
  dti DECIMAL(8,4),
  units INT,
  qualifying_rate DECIMAL(8,5),
  cashout_amount DECIMAL(18,2),
  high_balance_flag BOOLEAN,
  jumbo_flag BOOLEAN,
  mi_flag BOOLEAN,
  first_time_homebuyer BOOLEAN
);

ALTER TABLE main.gold_cm.fact_gos ADD COLUMNS (
  note_structure_key INT,
  occupancy_key INT,
  property_type_key INT,
  fico INT,
  ltv DECIMAL(8,4),
  cltv DECIMAL(8,4),
  high_balance_flag BOOLEAN,
  jumbo_flag BOOLEAN,
  mi_flag BOOLEAN,
  llpa_pts DECIMAL(12,6)
);

ALTER TABLE main.gold_cm.fact_loan_sale ADD COLUMNS (
  note_structure_key INT,
  occupancy_key INT,
  property_type_key INT
);

MERGE INTO main.gold_cm.dim_occupancy t
USING (
  SELECT * FROM VALUES
    (1, 'primary'), (2, 'second'), (3, 'investment')
  AS s(occupancy_key, occupancy_code)
) s
ON t.occupancy_key = s.occupancy_key
WHEN NOT MATCHED THEN INSERT *;

MERGE INTO main.gold_cm.dim_property_type t
USING (
  SELECT * FROM VALUES
    (1, 'sfr', 1, FALSE),
    (2, 'pud', 1, TRUE),
    (3, 'condo', 1, TRUE),
    (4, 'coop', 1, TRUE),
    (5, '2_4_unit', 2, FALSE),
    (6, 'manufactured', 1, FALSE),
    (7, 'attached', 1, FALSE)
  AS s(property_type_key, property_type_code, units_typical, project_flag)
) s
ON t.property_type_key = s.property_type_key
WHEN NOT MATCHED THEN INSERT *;

MERGE INTO main.gold_cm.dim_note_structure t
USING (
  SELECT * FROM VALUES
    (1, 'FIX_30', 'fixed', CAST(NULL AS STRING), CAST(NULL AS DECIMAL(8,2)), CAST(NULL AS INT), CAST(NULL AS INT), FALSE, CAST(NULL AS INT), 'none', CAST(NULL AS INT), FALSE, CAST(NULL AS INT), FALSE, CAST(NULL AS INT)),
    (2, 'FIX_15', 'fixed', NULL, NULL, NULL, NULL, FALSE, NULL, 'none', NULL, FALSE, NULL, FALSE, NULL),
    (3, 'ARM_5_6_SOFR', 'arm', 'sofr', CAST(300.00 AS DECIMAL(8,2)), 60, 6, FALSE, NULL, 'none', NULL, FALSE, NULL, FALSE, NULL),
    (4, 'ARM_7_6_SOFR', 'arm', 'sofr', CAST(300.00 AS DECIMAL(8,2)), 84, 6, FALSE, NULL, 'none', NULL, FALSE, NULL, FALSE, NULL),
    (5, 'FIX_30_IO10', 'fixed', NULL, NULL, NULL, NULL, TRUE, 120, 'none', NULL, FALSE, NULL, FALSE, NULL),
    (6, 'FIX_30_BD21', 'fixed', NULL, NULL, NULL, NULL, FALSE, NULL, '2_1', 24, FALSE, NULL, FALSE, NULL),
    (7, 'FIX_30_BD10', 'fixed', NULL, NULL, NULL, NULL, FALSE, NULL, '1_0', 12, FALSE, NULL, FALSE, NULL)
  AS s(note_structure_key, note_structure_code, amortization_type, arm_index, arm_margin_bps, arm_initial_period_mo, arm_reset_period_mo, io_flag, io_term_months, buydown_type, buydown_term_months, prepay_penalty_flag, prepay_term_months, balloon_flag, balloon_term_months)
) s
ON t.note_structure_key = s.note_structure_key
WHEN NOT MATCHED THEN INSERT *;

CREATE OR REPLACE VIEW main.gold_cm.v_lock_eligibility AS
SELECT e.*, n.note_structure_code, n.amortization_type, n.io_flag, n.buydown_type,
       p.property_type_code, o.occupancy_code
FROM main.gold_cm.fact_loan_eligibility e
LEFT JOIN main.gold_cm.dim_note_structure n ON n.note_structure_key = e.note_structure_key
LEFT JOIN main.gold_cm.dim_property_type p ON p.property_type_key = e.property_type_key
LEFT JOIN main.gold_cm.dim_occupancy o ON o.occupancy_key = e.occupancy_key
WHERE e.event_type = 'lock';

CREATE OR REPLACE VIEW main.gold_cm.v_lock_snapshot_with_note AS
SELECT s.*, n.note_structure_code, n.amortization_type, n.arm_index,
       n.io_flag, n.io_term_months, n.buydown_type,
       p.property_type_code, o.occupancy_code
FROM main.gold_cm.fact_lock_snapshot_daily s
LEFT JOIN main.gold_cm.dim_note_structure n ON n.note_structure_key = s.note_structure_key
LEFT JOIN main.gold_cm.dim_property_type p ON p.property_type_key = s.property_type_key
LEFT JOIN main.gold_cm.dim_occupancy o ON o.occupancy_key = s.occupancy_key;
