---
name: security-review
description: Review auth, authorization, input handling, secrets, file uploads, API endpoints, payments, or sensitive data changes for concrete security risk.
---

# Security Review

Use this before signing off security-sensitive code.

## Checklist

Check for:

- Hardcoded secrets, tokens, credentials, or private URLs
- Missing input validation at system boundaries
- SQL/command/template injection
- XSS or unsafe HTML rendering
- Broken authentication or authorization checks
- Insecure session, cookie, CSRF, CORS, or redirect handling
- File upload path traversal, type confusion, oversized payloads, or unsafe storage
- SSRF and unsafe outbound fetches
- Sensitive data in logs, errors, telemetry, fixtures, screenshots, or tests
- Payment, billing, or permission state transitions without auditability

## Flow

1. Identify trust boundaries and attacker-controlled inputs.
2. Trace the sensitive operation from entry point to side effect.
3. Verify validation, authorization, and error handling happen before the side effect.
4. Check config and deployment assumptions that change risk.
5. Prefer concrete findings over generic warnings.

## Severity

- Critical: credential exposure, auth bypass, data loss, remote code execution
- High: likely exploit or sensitive data exposure
- Medium: defense gap with plausible exploit path
- Low: hardening or hygiene issue

## Finish

Return findings by severity with file/symbol evidence, exploit condition, and minimal mitigation. Say explicitly when no actionable issues were found.
