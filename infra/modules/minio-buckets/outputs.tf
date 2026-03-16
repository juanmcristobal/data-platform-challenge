output "bucket_arns" {
  description = "Bucket ARNs keyed by bucket name."
  value       = module.data_lake_buckets.bucket_arns
}

output "bucket_names" {
  description = "Bucket names keyed by bucket name."
  value       = module.data_lake_buckets.bucket_names
}
