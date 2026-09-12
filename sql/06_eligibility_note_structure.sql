-- Schema gaps 1 and 2: eligibility/LLPA attributes + ARM/IO/buydown note structure.
-- Additive on gold_cm from 05_gold_star_ddl.sql. Databricks SQL.
-- Full file in working copy matches this commit.

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_note_structure (
  note_structure_key INT NOT NULL,
  note_structure_code STRING NOT NULL,
  amortization_type STRING NOT NULL COMMENT 'fixed|arm',
  arm_index STRING,
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
) USING DELTA;

ALTER TABLE main.gold_cm.dim_product ADD COLUMNS (
  default_note_structure_key INT,
  qualifying_rate_method STRING
);

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_property_type (
  property_type_key INT NOT NULL,
  property_type_code STRING NOT NULL,
  units_typical INT,
  project_flag BOOLEAN
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_occupancy (
  occupancy_key INT NOT NULL,
  occupancy_code STRING NOT NULL
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
) USING DELTA PARTITIONED BY (as_of_date);

ALTER TABLE main.gold_cm.fact_lock_snapshot_daily ADD COLUMNS (
  note_structure_key INT,
  occupancy_key INT,
  property_type_key INT,
  hedge_coupon_bucket_key INT,
  fico INT, ltv DECIMAL(8,4), cltv DECIMAL(8,4), dti DECIMAL(8,4),
  units INT, high_balance_flag BOOLEAN, jumbo_flag BOOLEAN, mi_flag BOOLEAN
);

ALTER TABLE main.gold_cm.fact_loan_fund ADD COLUMNS (
  note_structure_key INT, occupancy_key INT, property_type_key INT,
  fico INT, ltv DECIMAL(8,4), cltv DECIMAL(8,4), dti DECIMAL(8,4),
  units INT, qualifying_rate DECIMAL(8,5), cashout_amount DECIMAL(18,2),
  high_balance_flag BOOLEAN, jumbo_flag BOOLEAN, mi_flag BOOLEAN,
  first_time_homebuyer BOOLEAN
);

ALTER TABLE main.gold_cm.fact_gos ADD COLUMNS (
  note_structure_key INT, occupancy_key INT, property_type_key INT,
  fico INT, ltv DECIMAL(8,4), cltv DECIMAL(8,4),
  high_balance_flag BOOLEAN, jumbo_flag BOOLEAN, mi_flag BOOLEAN,
  llpa_pts DECIMAL(12,6)
);

ALTER TABLE main.gold_cm.fact_loan_sale ADD COLUMNS (
  note_structure_key INT, occupancy_key INT, property_type_key INT
);
