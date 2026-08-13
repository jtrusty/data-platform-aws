# Production safety profile. This file contains configuration only;
# credentials and secret values must never be added to committed tfvars.
force_destroy_buckets              = false
landing_expiration_days            = 30
athena_results_expiration_days     = 30
artifact_expiration_days           = 365
noncurrent_version_expiration_days = 90
versioned_bucket_purposes          = ["bronze", "silver", "artifacts"]
queue_visibility_timeout_seconds   = 300
queue_message_retention_seconds    = 345600
dlq_message_retention_seconds      = 1209600
queue_max_receive_count            = 5
metadata_read_capacity             = 1
metadata_write_capacity            = 1
metadata_point_in_time_recovery    = true
metadata_deletion_protection       = true
secret_recovery_window_days        = 30
secret_names                       = []
