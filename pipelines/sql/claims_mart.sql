-- pipelines/sql/claims_mart.sql
-- Cleaned → Mart Aggregations
-- MediFlow | Day 6 | ELT Pipeline

INSERT INTO `mediflow-solutions.mediflow_mart.claims_mart`
SELECT
  DATE(created_at)               AS claim_date,
  doctor,
  diagnosis_code,
  COUNT(claim_id)                AS total_claims,
  SUM(amount)                    AS total_amount,
  AVG(amount)                    AS avg_amount,
  MAX(amount)                    AS max_amount,
  MIN(amount)                    AS min_amount,
  COUNTIF(status = 'APPROVED')   AS approved_count,
  COUNTIF(status = 'REJECTED')   AS rejected_count,
  COUNTIF(status = 'PENDING')    AS pending_count,
  CURRENT_TIMESTAMP()            AS updated_at

FROM `mediflow-solutions.mediflow_clean.clean_claims`

GROUP BY
  claim_date,
  doctor,
  diagnosis_code;