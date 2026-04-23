#!/usr/bin/env bash
# Hydra shared constants — sourced by all hooks and utilities

HYDRA_VERSION="1.0.0"

# State file names
HYDRA_AUDIT_FILE="state/audit.jsonl"
HYDRA_METRICS_FILE="state/metrics.jsonl"
HYDRA_LEARNINGS_FILE="state/learnings.json"
HYDRA_CONFIG_FILE="state/config.json"

# Size limits
HYDRA_MAX_AUDIT_BYTES=10485760         # 10MB (rotate at 10MB)
HYDRA_MAX_METRICS_BYTES=10485760       # 10MB

# Severity levels
HYDRA_SEVERITY_CRITICAL="critical"
HYDRA_SEVERITY_HIGH="high"
HYDRA_SEVERITY_MEDIUM="medium"
HYDRA_SEVERITY_LOW="low"
HYDRA_SEVERITY_INFO="info"

# Shannon entropy thresholds (R2)
HYDRA_ENTROPY_THRESHOLD="4.5"
HYDRA_ENTROPY_MIN_LEN=20

# Strictness modes
HYDRA_MODE_STRICT="strict"
HYDRA_MODE_BALANCED="balanced"
HYDRA_MODE_PERMISSIVE="permissive"
HYDRA_DEFAULT_MODE="balanced"

# Lock config
HYDRA_LOCK_SUFFIX=".lock"

# Session cache prefix
HYDRA_CACHE_PREFIX="/tmp/hydra-"

# R8 EMA Posture Decay — priors reserved for future Bayesian upgrade
# Beta(2,8) optimistic prior. Currently unused by shared/scripts/learnings.py (pure EMA path).
# Keep declared so a future Bayesian-posterior variant can read them without a config change.
HYDRA_THREAT_PRIOR_ALPHA=2
HYDRA_THREAT_PRIOR_BETA=8

# EMA learning rate (R8: EMA Posture Decay)
HYDRA_GAUSS_ALPHA="0.3"

# Secret masking
HYDRA_MASK_PREFIX_LEN=4
HYDRA_MASK_SUFFIX_LEN=4

# Subcommand overflow threshold (R7)
HYDRA_SUBCOMMAND_LIMIT=50

# Pattern file locations (relative to shared/)
HYDRA_PATTERNS_SECRETS="patterns/secrets.json"
HYDRA_PATTERNS_VULNS="patterns/vulns.json"
HYDRA_PATTERNS_DANGEROUS="patterns/dangerous-ops.json"
HYDRA_PATTERNS_CONFIG="patterns/config-attacks.json"
HYDRA_PATTERNS_SLOPSQUAT="patterns/slopsquatting.json"
