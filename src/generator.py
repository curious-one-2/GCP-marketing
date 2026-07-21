import json
import random
import time
from datetime import datetime
from faker import Faker

fake = Faker()

# High-level configurations to make the data realistic
VENDORS = [f"Vendor_{name.replace(' ', '_')}" for name in [fake.company() for _ in range(5)]]
CAMPAIGNS = {
   vendor: [f"CAMP_{random.randint(1000, 9999)}" for _ in range(2)]
   for vendor in VENDORS
}
PAGES = ["/homepage", "/search_results", "/product_details", "/checkout_success"]

def generate_ad_event():
   vendor = random.choice(VENDORS)
   campaign = random.choice(CAMPAIGNS[vendor])
   event_type = random.choices(["impression", "click"], weights=[0.85, 0.15])[0]

   # Clicks cost money based on Cost-Per-Click; impressions are free or minimal
   cost = round(random.uniform(0.25, 2.50), 2) if event_type == "click" else 0.00

   event = {
       "event_id": fake.uuid4(),
       "timestamp": datetime.utcnow().isoformat() + "Z",
       "vendor_id": vendor,
       "campaign_id": campaign,
       "event_type": event_type,
       "page_url": random.choice(PAGES),
       "cost": cost,
       "cookie_id": fake.md5()[:16]
   }
   return event

if __name__ == "__main__":
   print("Starting Retail Media Platform Mock Data Stream (Ctrl+C to stop)...")
   try:
       while True:
           mock_event = generate_ad_event()
           print(json.dumps(mock_event, indent=2))
           time.sleep(1) # Simulates 1 event per second
   except KeyboardInterrupt:
       print("\nStream stopped.")
