-- pipelines/sql/fraud_detection.sql
-- Fraud Detection Rules — HIGH / MEDIUM / LOW Risk Classification
-- MediFlow | Day 7 | Fraud Detection Pipeline

INSERT INTO `mediflow-solutions.mediflow_mart.fraud_alerts`
SELECT
  claim_id,
  patient_id,
  doctor,
  diagnosis_code,
  amount,
  status,
  created_at,

  CASE
    -- HIGH Risk Rules
    WHEN amount > 50000                          THEN 'HIGH'
    WHEN diagnosis_code IN ('Z00', 'Z01', 'Z02')
         AND amount > 30000                      THEN 'HIGH'

    -- MEDIUM Risk Rules
    WHEN amount BETWEEN 20000 AND 50000          THEN 'MEDIUM'
    WHEN status = 'PENDING'
         AND amount > 15000                      THEN 'MEDIUM'

    -- LOW Risk Rules
    WHEN diagnosis_code NOT LIKE 'A%'
         AND diagnosis_code NOT LIKE 'B%'
         AND amount > 5000                       THEN 'LOW'

    ELSE 'SAFE'
  END AS risk_level,

  CASE
    WHEN amount > 50000                          THEN 'Amount exceeds ₹50,000 threshold'
    WHEN diagnosis_code IN ('Z00', 'Z01', 'Z02')
         AND amount > 30000                      THEN 'Routine diagnosis with high amount'
    WHEN amount BETWEEN 20000 AND 50000          THEN 'Amount in medium risk range'
    WHEN status = 'PENDING'
         AND amount > 15000                      THEN 'High value claim pending approval'
    WHEN diagnosis_code NOT LIKE 'A%'
         AND diagnosis_code NOT LIKE 'B%'
         AND amount > 5000                       THEN 'Unusual diagnosis code pattern'
    ELSE 'Normal claim'
  END AS reason,

  CURRENT_TIMESTAMP() AS flagged_at

FROM `mediflow-solutions.mediflow_clean.clean_claims`

WHERE claim_id NOT IN (
  SELECT claim_id
  FROM `mediflow-solutions.mediflow_mart.fraud_alerts`
);