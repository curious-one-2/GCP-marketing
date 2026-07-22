import json
import os
import random
import time
import uuid
from google.cloud import pubsub_v1

# Fetch GCP project dynamically or set your project ID string manually
project_id = os.popen("gcloud config get-value project").read().strip()
topic_id = "ad-events-stream"

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project_id, topic_id)

# Helper function to format and send payload to Pub/Sub
def publish_event(ad_id, user_id, event_type, cost):
    event = {
        "event_id": str(uuid.uuid4()),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "ad_id": ad_id,
        "user_id": user_id,
        "event_type": event_type,
        "cost": cost
    }
    data = json.dumps(event).encode("utf-8")
    publisher.publish(topic_path, data)
    print(f"Published Event ID: {event['event_id']} | Type: {event_type:<10} | Ad: {ad_id} | User: {user_id} | Cost: ${cost}")

print(f"Starting stateful stream to GCP Pub/Sub topic: {topic_path}")
print("Press Ctrl+C to stop streaming.\n")

# Funnel Probabilities
CLICK_PROBABILITY = 0.15       # 15% Click-Through Rate (CTR)
CONVERSION_PROBABILITY = 0.05  # 5% Conversion Rate (CVR)

try:
    while True:
        # Generate target entity for this user session
        ad_id = f"ad_{random.randint(100, 999)}"
        user_id = f"usr_{random.randint(1000, 9999)}"

        # 1. ALWAYS emit an Impression first (Cost = $0.00 for CPM/CPC baseline)
        publish_event(ad_id, user_id, "impression", 0.00)
        time.sleep(0.2)

        # 2. Roll for Click (Only happens AFTER an impression)
        if random.random() < CLICK_PROBABILITY:
            click_cost = round(random.uniform(0.50, 2.50), 2)
            publish_event(ad_id, user_id, "click", click_cost)
            time.sleep(0.2)

            # 3. Roll for Conversion (Only happens AFTER a click)
            if random.random() < CONVERSION_PROBABILITY:
                publish_event(ad_id, user_id, "conversion", 0.00)
                time.sleep(0.2)

        print("-" * 65)
        time.sleep(1)  # Delay between user sessions

except KeyboardInterrupt:
    print("\nStream producer stopped.")
