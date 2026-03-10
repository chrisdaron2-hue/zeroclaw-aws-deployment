
# outputs.tf

output "ecs_cluster_name" {
  value = aws_ecs_cluster.zeroclaw_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.zeroclaw_service.name
}

output "alb_dns_name" {
  value = aws_lb.zeroclaw_alb.dns_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.zeroclaw_bucket.bucket
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
