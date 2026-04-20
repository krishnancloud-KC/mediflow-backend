import json
import boto3
import os
from datetime import datetime

def handler(event, context):
    """
    GCP BigQuery నుంచి data S3 కి export చేస్తుంది.
    Cloud Scheduler లేదా manual trigger తో run అవుతుంది.
    """
    s3_client = boto3.client('s3')
    bucket_name = os.environ.get('BUCKET_NAME', 'mediflow-solutions-backup')

    # Sample claims data (production లో BigQuery నుంచి fetch అవుతుంది)
    claims_data = {
        "export_timestamp": datetime.utcnow().isoformat(),
        "project": "mediflow-solutions",
        "source": "GCP BigQuery mediflow_mart.claims_mart",
        "records": [
            {
                "claim_date": "2026-04-19",
                "doctor": "Dr. Smith",
                "diagnosis_code": "A001",
                "total_claims": 15,
                "total_amount": 125000.00,
                "approved_count": 10,
                "rejected_count": 3,
                "pending_count": 2
            },
            {
                "claim_date": "2026-04-19",
                "doctor": "Dr. Rao",
                "diagnosis_code": "B002",
                "total_claims": 8,
                "total_amount": 67500.00,
                "approved_count": 6,
                "rejected_count": 1,
                "pending_count": 1
            }
        ]
    }

    # S3 కి export
    file_key = f"exports/{datetime.utcnow().strftime('%Y/%m/%d')}/claims_export.json"

    s3_client.put_object(
        Bucket=bucket_name,
        Key=file_key,
        Body=json.dumps(claims_data, indent=2),
        ContentType='application/json'
    )

    print(f"✅ Export successful: s3://{bucket_name}/{file_key}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Export successful",
            "s3_path": f"s3://{bucket_name}/{file_key}",
            "records_exported": len(claims_data["records"])
        })
    }