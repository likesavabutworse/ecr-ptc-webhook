from prometheus_client import Counter, Histogram

ADMISSIONS = Counter(
    "ecr_ptc_webhook_admissions_total",
    "Admission review requests handled by the webhook.",
    ["result"],
)

PATCHES = Counter(
    "ecr_ptc_webhook_patches_total",
    "Image rewrites emitted, labeled by upstream registry prefix.",
    ["ecr_prefix"],
)

SKIPS = Counter(
    "ecr_ptc_webhook_skipped_total",
    "Container images left unchanged, labeled by reason.",
    ["reason"],
)

DURATION = Histogram(
    "ecr_ptc_webhook_admission_duration_seconds",
    "Time spent handling a single admission review.",
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)
