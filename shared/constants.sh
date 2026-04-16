#!/usr/bin/env bash
# Reaper shared constants — sourced by all hooks and utilities

REAPER_VERSION="1.0.0"

# State file names
REAPER_AUDIT_FILE="state/audit.jsonl"
REAPER_METRICS_FILE="state/metrics.jsonl"
REAPER_LEARNINGS_FILE="state/learnings.json"
REAPER_CONFIG_FILE="state/config.json"

# Size limits
REAPER_MAX_AUDIT_BYTES=10485760         # 10MB (rotate at 10MB)
REAPER_MAX_METRICS_BYTES=10485760       # 10MB

# Severity levels
REAPER_SEVERITY_CRITICAL="critical"
REAPER_SEVERITY_HIGH="high"
REAPER_SEVERITY_MEDIUM="medium"
REAPER_SEVERITY_LOW="low"
REAPER_SEVERITY_INFO="info"

# Shannon entropy thresholds (R2)
REAPER_ENTROPY_THRESHOLD="4.5"
REAPER_ENTROPY_MIN_LEN=20

# Strictness modes
REAPER_MODE_STRICT="strict"
REAPER_MODE_BALANCED="balanced"
REAPER_MODE_PERMISSIVE="permissive"
REAPER_DEFAULT_MODE="balanced"

# Lock config
REAPER_LOCK_SUFFIX=".lock"

# Session cache prefix
REAPER_CACHE_PREFIX="/tmp/reaper-"

# Bayesian Threat Convergence priors (R8)
# Beta(2,8) — optimistic prior: most sessions are safe
REAPER_THREAT_PRIOR_ALPHA=2
REAPER_THREAT_PRIOR_BETA=8

# EMA learning rate (R8: Bayesian Threat Convergence)
REAPER_GAUSS_ALPHA="0.3"

# Secret masking
REAPER_MASK_PREFIX_LEN=4
REAPER_MASK_SUFFIX_LEN=4

# Subcommand overflow threshold (R7)
REAPER_SUBCOMMAND_LIMIT=50

# Pattern file locations (relative to shared/)
REAPER_PATTERNS_SECRETS="patterns/secrets.json"
REAPER_PATTERNS_VULNS="patterns/vulns.json"
REAPER_PATTERNS_DANGEROUS="patterns/dangerous-ops.json"
REAPER_PATTERNS_CONFIG="patterns/config-attacks.json"
REAPER_PATTERNS_SLOPSQUAT="patterns/slopsquatting.json"
