import functions_framework
import json
import random
from datetime import datetime
from google.cloud import bigquery

PROJECT_ID = "mediflow-solutions"
DATASET_ID = "mediflow_raw"
TABLE_ID = "raw_claims"

@functions_framework.http
def appointment_checker(request):
    client = bigquery.Client(project=PROJECT_ID)
    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

    doctors = ["Dr. Sharma", "Dr. Reddy", "Dr. Patel", "Dr. Kumar"]
    diagnoses = ["I10", "E11.9", "J18.9", "K21.0", "M54.5"]
    statuses = ["PENDING", "APPROVED", "REJECTED"]

    claims = []
    for i in range(5):
        claim = {
            "claim_id": f"APT-{datetime.now().strftime('%Y%m%d%H%M%S')}-{i}",
            "patient_id": f"PAT-{random.randint(1000, 9999)}",
            "doctor": random.choice(doctors),
            "diagnosis_code": random.choice(diagnoses),
            "amount": round(random.uniform(500, 75000), 2),
            "status": random.choice(statuses),
            "created_at": datetime.utcnow().isoformat()
        }
        claims.append(claim)

    errors = client.insert_rows_json(table_ref, claims)

    if errors:
        return json.dumps({"status": "error", "errors": errors}), 500

    return json.dumps({
        "status": "success",
        "inserted": len(claims),
        "timestamp": datetime.utcnow().isoformat()
    }), 200