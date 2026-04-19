-- pipelines/sql/clean_claims.sql
-- Raw → Cleaned Transform
-- MediFlow | Day 6 | ELT Pipeline

INSERT INTO `mediflow-solutions.mediflow_clean.clean_claims`
SELECT
  claim_id,
  patient_id,
  doctor,
  diagnosis_code,
  CAST(amount AS FLOAT64)        AS amount,
  UPPER(TRIM(status))            AS status,
  TIMESTAMP(created_at)          AS created_at,
  CURRENT_TIMESTAMP()            AS processed_at

FROM `mediflow-solutions.mediflow_raw.raw_claims`

WHERE
  -- NULL checks
  claim_id       IS NOT NULL
  AND patient_id IS NOT NULL
  AND doctor     IS NOT NULL
  AND diagnosis_code IS NOT NULL
  AND amount     IS NOT NULL
  AND status     IS NOT NULL
  AND created_at IS NOT NULL

  -- Amount validation
  AND CAST(amount AS FLOAT64) > 0

  -- No duplicates
  AND claim_id NOT IN (
    SELECT claim_id
    FROM `mediflow-solutions.mediflow_clean.clean_claims`
  );