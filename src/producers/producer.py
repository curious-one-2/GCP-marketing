import json
import random
import time
import uuid
import os
from google.cloud import pubsub_v1

# Fetch GCP project dynamically or set your project ID string manually
project_id = os.popen("gcloud config get-value project").read().strip()
topic_id = "ad-events-stream"

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project_id, topic_id)

event_types = ["impression", "click", "conversion"]

print(f"Starting stream to GCP Pub/Sub topic: {topic_path}")
print("Press Ctrl+C to stop streaming.\n")

try:
    while True:
        # Construct JSON payload matching your BigQuery schema
        event = {
            "event_id": str(uuid.uuid4()),
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "ad_id": f"ad_{random.randint(100, 999)}",
            "user_id": f"usr_{random.randint(1000, 9999)}",
            "event_type": random.choice(event_types),
            "cost": round(random.uniform(0.05, 2.50), 2)
        }

        # Encode dict as JSON bytes
        data = json.dumps(event).encode("utf-8")

        # Publish to Pub/Sub
        future = publisher.publish(topic_path, data)
        print(f"Published Event ID: {event['event_id']} | Type: {event['event_type']} | Cost: ${event['cost']}")

        time.sleep(1)  # Stream 1 event per second
except KeyboardInterrupt:
    print("\nStream producer stopped.")
