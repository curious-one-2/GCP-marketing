output "pubsub_topic_name" {
  value = google_pubsub_topic.ad_events.name
}

output "dlq_topic_name" {
  value = google_pubsub_topic.ad_events_dlq.name
}