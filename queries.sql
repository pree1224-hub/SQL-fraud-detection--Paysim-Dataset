-- ============================================================
-- Fraud Detection with SQL: Rule-Based Transaction Monitoring
-- Dataset: PaySim (table: transactions) | Tool: DB Browser for SQLite
-- Author: Preeti Punia
-- ============================================================


-- ------------------------------------------------------------
-- RULE 1: Account drain
-- Flag TRANSFER / CASH_OUT where the amount equals the sender's
-- full balance and the sender's balance ends at zero.
-- ------------------------------------------------------------

-- 1A. Flagged transactions vs true fraud
SELECT type,
       COUNT(*) AS flagged,
       SUM(isFraud) AS true_fraud
FROM transactions
WHERE type IN ('TRANSFER','CASH_OUT')
  AND amount = oldbalanceOrg
  AND newbalanceOrig = 0
GROUP BY type;

-- 1B. Recall and false positives
SELECT type,
       COUNT(*) AS total_txns,
       SUM(isFraud) AS total_fraud,
       SUM(CASE WHEN amount = oldbalanceOrg
                 AND newbalanceOrig = 0
                 AND isFraud = 1 THEN 1 ELSE 0 END) AS caught,
       SUM(CASE WHEN amount = oldbalanceOrg
                 AND newbalanceOrig = 0
                 AND isFraud = 0 THEN 1 ELSE 0 END) AS false_positives
FROM transactions
WHERE type IN ('TRANSFER','CASH_OUT')
GROUP BY type;


-- ------------------------------------------------------------
-- INVESTIGATING FRAUD MISSED BY RULE 1
-- ------------------------------------------------------------

-- Sample of missed fraud (first 20 rows only; not representative)
SELECT type, amount, oldbalanceOrg, newbalanceOrig
FROM transactions
WHERE isFraud = 1
  AND type IN ('TRANSFER','CASH_OUT')
  AND NOT (amount = oldbalanceOrg AND newbalanceOrig = 0)
LIMIT 20;

-- Testing candidate rules on transactions Rule 1 did not flag
--   R2: zero balance sender  -> rejected (about 1.3M false positives)
--   R3: overdraw to zero     -> rejected (about 1.18M false positives)
--   R4: exactly 10,000,000   -> kept (145 caught, 0 false positives)
SELECT
  CASE WHEN oldbalanceOrg = 0 AND amount > 0 THEN 'R2: zero balance sender'
       WHEN amount > oldbalanceOrg AND newbalanceOrig = 0 THEN 'R3: overdraw to zero'
       WHEN amount = 10000000 THEN 'R4: 10M cap'
       ELSE 'no rule' END AS rule,
  COUNT(*) AS flagged,
  SUM(isFraud) AS true_fraud,
  COUNT(*) - SUM(isFraud) AS false_positives
FROM transactions
WHERE type IN ('TRANSFER','CASH_OUT')
  AND NOT (amount = oldbalanceOrg AND newbalanceOrig = 0)
GROUP BY rule;


-- ------------------------------------------------------------
-- THE LAST 44 MISSED CASES (after Rules 1 and 4)
-- ------------------------------------------------------------
SELECT type, amount, oldbalanceOrg, newbalanceOrig,
       oldbalanceDest, newbalanceDest
FROM transactions
WHERE isFraud = 1
  AND type IN ('TRANSFER','CASH_OUT')
  AND NOT (amount = oldbalanceOrg AND newbalanceOrig = 0)
  AND amount <> 10000000;


-- ------------------------------------------------------------
-- RULE 5: TRANSFER with no balance movement
-- Sender balance unchanged; destination balance is 0 before and after.
-- Result: 13 fraud, 5 false positives -> kept.
-- ------------------------------------------------------------
SELECT isFraud, COUNT(*) AS txns
FROM transactions
WHERE type = 'TRANSFER'
  AND amount > 0
  AND amount <> 10000000
  AND oldbalanceOrg = newbalanceOrig
  AND oldbalanceDest = 0
  AND newbalanceDest = 0
GROUP BY isFraud;
