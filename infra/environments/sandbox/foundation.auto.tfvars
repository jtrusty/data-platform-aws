# Disposable, lowest-cost profile. This file contains configuration only;
# credentials and secret values must never be added to committed tfvars.
force_destroy_buckets                 = true
landing_expiration_days               = 7
athena_results_expiration_days        = 7
artifact_expiration_days              = 30
noncurrent_version_expiration_days    = 7
versioned_bucket_purposes             = ["bronze", "artifacts"]
queue_visibility_timeout_seconds      = 300
queue_message_retention_seconds       = 345600
dlq_message_retention_seconds         = 1209600
queue_max_receive_count               = 5
metadata_read_capacity                = 1
metadata_write_capacity               = 1
metadata_point_in_time_recovery       = false
metadata_deletion_protection          = false
secret_recovery_window_days           = 0
secret_names                          = []
analytics_availability_zones          = ["us-east-2a", "us-east-2b", "us-east-2c"]
athena_bytes_scanned_cutoff_per_query = 10737418240
redshift_base_capacity                = 4
redshift_max_capacity                 = 4
redshift_monthly_rpu_hours            = 16
redshift_max_query_execution_seconds  = 900
redshift_log_retention_days           = 7
