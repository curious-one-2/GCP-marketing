import json
import os
import time
import uuid
from google.cloud import pubsub_v1

project_id = os.popen("gcloud config get-value project").read().strip()
topic_id = "ad-events-stream"

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project_id, topic_id)

print(f"Publishing test payloads to {topic_path}...\n")

# 1. VALID event matching BigQuery schema
valid_event = {
    "event_id": str(uuid.uuid4()),
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "ad_id": "ad_777",
    "user_id": "usr_8888",
    "event_type": "click",
    "cost": 1.45
}
publisher.publish(topic_path, json.dumps(valid_event).encode("utf-8"))
print("Sent VALID event.")

# 2. MALFORMED event (Schema mismatch: cost is non-numeric, missing required event_id)
invalid_event = {
    "timestamp": "invalid_date_format",
    "ad_id": "ad_999",
    "cost": "NOT_A_FLOAT"
}
publisher.publish(topic_path, json.dumps(invalid_event).encode("utf-8"))
print("Sent MALFORMED JSON event.")

# 3. CORRUPTED event (Raw plain string bytes, not JSON)
publisher.publish(topic_path, b"RAW_CORRUPTED_NON_JSON_BYTES")
print("Sent RAW CORRUPTED STRING event.\n")

print("Finished sending test payloads.")
