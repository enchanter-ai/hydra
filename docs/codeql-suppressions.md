# CodeQL alert suppression log

Every dismissed alert lives here with file/line context, the analyzer's claim, and the verified justification. Pasted verbatim into the GitHub Security UI as the dismissal reason.

## py/clear-text-logging-sensitive-data — `shared/scripts/pattern-engine.py:172`

**Verdict:** false positive — dismiss as "Used in tests".

**Code under analysis:**

```python
findings = scan_file(file_path, patterns_path)
print(json.dumps(findings, indent=2))
```

**Why CodeQL flagged it.** The analyzer follows taint from `scan_file` (which loads pattern names like `AWS_ACCESS_KEY_PATTERN`, `BEARER_TOKEN_PATTERN`, `STRIPE_API_KEY_PATTERN` etc. into its in-memory taxonomy) to the `print()` sink and concludes "sensitive data flows to clear-text output." The string literals are *names of secret categories*, not values of any secret.

**Why it is a false positive.** This is hydra's secret-scanner reference engine. Its entire purpose is to take a file path, match against a regex catalogue of secret-looking patterns, and emit a JSON report of which patterns matched where. The output is the scanner's diagnostic report — the same kind of output `git-secrets`, `trufflehog`, `gitleaks`, and GitHub's own secret-scanning service produce. Suppressing this alert does not weaken the security posture; refusing to emit findings would.

**What is NOT being logged.** The `findings` payload contains:
- pattern name (e.g. `"aws_access_key_v4"`)
- file path + line number where the match occurred
- a redacted 8-char SHA-256 prefix of the matched substring

The full matched substring is NEVER printed. See [shared/scripts/pattern-engine.py:140-158](../shared/scripts/pattern-engine.py#L140-L158) for the redaction.

**Operator dismissal instructions.**

1. Open https://github.com/enchanted-plugins/hydra/security/code-scanning
2. Click the open `py/clear-text-logging-sensitive-data` alert
3. "Dismiss alert" → reason: **"False positive"**
4. Paste this paragraph as the comment:
   > Scanner-of-scanners false positive. `pattern-engine.py` is hydra's reference secret-scanner; its `findings` output contains pattern *names* and SHA-256-prefixed hashes, never the matched secret values. Redaction happens at scan time (pattern-engine.py:140-158). Logging this output is the scanner's contract — refusing to log it would defeat the tool's purpose. Documented at docs/codeql-suppressions.md.
5. Submit.

## Suppression policy

- Every dismissal must point at a documented justification in this file. No bare dismissals.
- Re-review on every major version bump. If the line moves, the dismissal cites the old line — update both the file/line ref here and the dismissal comment in GitHub.
- "Used in tests" / "Won't fix" / "False positive" are the only accepted categories. "Won't fix" is reserved for code that genuinely is sensitive but is gated behind an explicit operator opt-in (`HYDRA_DEBUG=1` etc.); it must additionally reference the gate in the justification.
