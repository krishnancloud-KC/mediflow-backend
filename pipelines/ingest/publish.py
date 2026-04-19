import json
import random
import uuid
from datetime import datetime
#from google.cloud import pubsub_v1

from google.cloud import bigquery

# Config
PROJECT_ID = "mediflow-solutions"
TOPIC_ID = "claims-stream"
DATASET = "mediflow_raw"
TABLE = "raw_claims"

# Sample data
DOCTORS = ["Dr. Sharma", "Dr. Reddy", "Dr. Patel", "Dr. Kumar", "Dr. Singh"]
DIAGNOSES = ["A01.0", "B02.1", "C03.2", "D04.3", "E05.4"]
STATUSES = ["PENDING", "APPROVED", "REJECTED"]

def generate_claim():
    return {
        "claim_id": str(uuid.uuid4()),
        "patient_id": f"P{random.randint(1000, 9999)}",
        "doctor": random.choice(DOCTORS),
        "diagnosis_code": random.choice(DIAGNOSES),
        "amount": round(random.uniform(500, 75000), 2),
        "status": random.choice(STATUSES),
        "created_at": datetime.utcnow().isoformat()
    }
def publish_to_pubsub(claim):
print(f"[SKIPPED] PubSub: {claim['claim_id']}")
def insert_to_bigquery(claim):
    client = bigquery.Client(project=PROJECT_ID)
    table_ref = f"{PROJECT_ID}.{DATASET}.{TABLE}"
    claim["created_at"] = datetime.utcnow().isoformat()
    errors = client.insert_rows_json(table_ref, [claim])
    if errors:
        print(f"BQ Error: {errors}")
    else:
        print(f"Inserted to BigQuery: {claim['claim_id']}")

def handler(request=None):
    """Cloud Function entry point"""
    claim = generate_claim()
    publish_to_pubsub(claim)
    insert_to_bigquery(claim)
    return f"Claim {claim['claim_id']} processed!", 200

if __name__ == "__main__":
    # Local test — 3 claims generate చేస్తుంది
    for i in range(3):
        claim = generate_claim()
        print(f"\nClaim {i+1}: {json.dumps(claim, indent=2)}")
        insert_to_bigquery(claim)