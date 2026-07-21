terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "project_number" {
  type        = string
  description = "GCP Project Number"
}

provider "google" {
  project = var.project_id
}

# 1. Primary Pub/Sub Topic
resource "google_pubsub_topic" "ad_events" {
  name = "ad-events-stream"
}

# 2. Dead-Letter Queue (DLQ) Topic
resource "google_pubsub_topic" "ad_events_dlq" {
  name = "ad-events-dlq-topic"
}

# 3. BigQuery Dataset (Satisfying Sandbox limits)
resource "google_bigquery_dataset" "retailmedia_ds" {
  dataset_id                      = "retailmedia_ds"
  description                     = "Dataset for streaming ad interaction logs and dead-letter records"
  location                        = "US"
  default_table_expiration_ms     = 3600000000 # 100 hours
  default_partition_expiration_ms = 3600000000 # 100 hours
}

# 4. Main Production BigQuery Table
resource "google_bigquery_table" "ad_events_table" {
  dataset_id          = google_bigquery_dataset.retailmedia_ds.dataset_id
  table_id            = "ad_events"
  deletion_protection = false

  schema = jsonencode([
    { name = "event_id",   type = "STRING",    mode = "REQUIRED" },
    { name = "timestamp",  type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "ad_id",      type = "STRING",    mode = "NULLABLE" },
    { name = "user_id",    type = "STRING",    mode = "NULLABLE" },
    { name = "event_type", type = "STRING",    mode = "NULLABLE" },
    { name = "cost",       type = "FLOAT",     mode = "NULLABLE" }
  ])
}

# 5. DLQ Audit BigQuery Table
resource "google_bigquery_table" "ad_events_dlq_table" {
  dataset_id          = google_bigquery_dataset.retailmedia_ds.dataset_id
  table_id            = "ad_events_dlq"
  deletion_protection = false

  schema = jsonencode([
    { name = "subscription_name", type = "STRING",    mode = "NULLABLE" },
    { name = "message_id",        type = "STRING",    mode = "NULLABLE" },
    { name = "publish_time",      type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "attributes",        type = "JSON",      mode = "NULLABLE" },
    { name = "data",              type = "JSON",      mode = "NULLABLE" }
  ])
}

# 6. IAM Grants for Pub/Sub Service Account
resource "google_project_iam_member" "pubsub_bq_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_topic_iam_member" "pubsub_dlq_publisher" {
  topic  = google_pubsub_topic.ad_events_dlq.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "pubsub_subscriber_ack" {
  subscription = "projects/${var.project_id}/subscriptions/ad-events-bq-sub"
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  depends_on = [google_pubsub_subscription.bq_sub]
}

# 7. Main BigQuery Subscription with DLQ Policy
resource "google_pubsub_subscription" "bq_sub" {
  name  = "ad-events-bq-sub"
  topic = google_pubsub_topic.ad_events.name

  bigquery_config {
    table            = "${google_bigquery_table.ad_events_table.project}.${google_bigquery_table.ad_events_table.dataset_id}.${google_bigquery_table.ad_events_table.table_id}"
    use_table_schema = true
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.ad_events_dlq.id
    max_delivery_attempts = 5
  }

  depends_on = [
    google_project_iam_member.pubsub_bq_writer,
    google_pubsub_topic_iam_member.pubsub_dlq_publisher
  ]
}

# 8. Subscription for DLQ Topic
resource "google_pubsub_subscription" "dlq_bq_sub" {
  name  = "ad-events-dlq-bq-sub"
  topic = google_pubsub_topic.ad_events_dlq.name

  bigquery_config {
    table          = "${google_bigquery_table.ad_events_dlq_table.project}.${google_bigquery_table.ad_events_dlq_table.dataset_id}.${google_bigquery_table.ad_events_dlq_table.table_id}"
    write_metadata = true
  }

  depends_on = [google_project_iam_member.pubsub_bq_writer]
}

# ------------------------------------------------------------------------------
# ANALYTICAL VIEWS
# ------------------------------------------------------------------------------

# View 1: Campaign / Ad Performance Metrics (CTR, CPC, Conversion Rate, Total Spend)
resource "google_bigquery_table" "vw_ad_performance_summary" {
  dataset_id          = google_bigquery_dataset.retailmedia_ds.dataset_id
  table_id            = "vw_ad_performance_summary"
  deletion_protection = false

  view {
    query = <<SQL
SELECT
  ad_id,
  COUNTIF(event_type = 'impression') AS total_impressions,
  COUNTIF(event_type = 'click') AS total_clicks,
  COUNTIF(event_type = 'conversion') AS total_conversions,
  -- CTR % = (Clicks / Impressions) * 100
  ROUND(
    SAFE_DIVIDE(COUNTIF(event_type = 'click'), COUNTIF(event_type = 'impression')) * 100, 2
  ) AS ctr_percentage,
  -- Conversion Rate % = (Conversions / Clicks) * 100
  ROUND(
    SAFE_DIVIDE(COUNTIF(event_type = 'conversion'), COUNTIF(event_type = 'click')) * 100, 2
  ) AS conversion_rate_pct,
  ROUND(SUM(cost), 2) AS total_ad_spend,
  -- CPC = Total Spend / Clicks
  ROUND(
    SAFE_DIVIDE(SUM(cost), COUNTIF(event_type = 'click')), 2
  ) AS avg_cpc
FROM
  `${var.project_id}.retailmedia_ds.ad_events`
WHERE
  ad_id IS NOT NULL
GROUP BY
  ad_id
ORDER BY
  total_ad_spend DESC
SQL
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.ad_events_table]
}

# View 2: Hourly Traffic Trends
resource "google_bigquery_table" "vw_hourly_traffic_trends" {
  dataset_id          = google_bigquery_dataset.retailmedia_ds.dataset_id
  table_id            = "vw_hourly_traffic_trends"
  deletion_protection = false

  view {
    query = <<SQL
SELECT
  TIMESTAMP_TRUNC(timestamp, HOUR) AS event_hour,
  COUNT(1) AS total_events,
  COUNTIF(event_type = 'impression') AS impressions,
  COUNTIF(event_type = 'click') AS clicks,
  COUNTIF(event_type = 'conversion') AS conversions,
  ROUND(SUM(cost), 2) AS hourly_spend
FROM
  `${var.project_id}.retailmedia_ds.ad_events`
WHERE
  timestamp IS NOT NULL
GROUP BY
  event_hour
ORDER BY
  event_hour DESC
SQL
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.ad_events_table]
}

# View 3: User Engagement
resource "google_bigquery_table" "vw_user_engagement" {
  dataset_id          = google_bigquery_dataset.retailmedia_ds.dataset_id
  table_id            = "vw_user_engagement"
  deletion_protection = false

  view {
    query = <<SQL
SELECT
  user_id,
  COUNT(DISTINCT ad_id) AS unique_ads_seen,
  COUNTIF(event_type = 'impression') AS total_impressions,
  COUNTIF(event_type = 'click') AS total_clicks,
  COUNTIF(event_type = 'conversion') AS total_conversions,
  ROUND(SUM(cost), 2) AS user_attributed_spend
FROM
  `${var.project_id}.retailmedia_ds.ad_events`
WHERE
  user_id IS NOT NULL
GROUP BY
  user_id
ORDER BY
  total_clicks DESC
SQL
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.ad_events_table]
}

output "pubsub_topic_name" {
  value = google_pubsub_topic.ad_events.name
}

output "dlq_topic_name" {
  value = google_pubsub_topic.ad_events_dlq.name
}
