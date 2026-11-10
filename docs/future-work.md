# Evidence revalidation and expiry policy

## Decision

Automatic expiry is **not enabled**. Existing approved pilot evidence remains
available to routing unless an administrator rejects it or an explicit
`valid_until` has already passed. This is intentional: an OpenStreetMap version
or edit timestamp proves neither that a road was inspected nor that its current
condition has changed.

The policy below is the design gate for turning automatic expiry on. It keeps a
route's treatment of missing evidence conservative: once evidence expires, the
road is **unknown**, never assumed smooth.

## Evidence lifecycle

```text
unverified --approve--> verified --revalidation due--> stale --expire--> expired
     |                      |                                |                 |
     +------reject--------> rejected <----reject--------------+                 |
                                  ^                                             |
                                  +-------new review / superseding evidence-----+
```

- **Unverified** — imported or submitted evidence; it never affects a route.
- **Verified** — an authorised reviewer accepted the source and claim; it may
  inform ranking until its revalidation deadline.
- **Stale** — the deadline has passed, but the automatic-expiry rollout has not
  progressed beyond its warning phase. It remains visible to reviewers with a
  prominent warning and is reported as ageing in route explanations.
- **Expired** — excluded from ranking and presented as unknown. It remains in
  the database and review workspace for audit.
- **Rejected** — excluded from ranking permanently unless superseded by a new
  evidence record. A rejection is not deleted or overwritten.

Initially, `stale` is an operational review state, not a new stored status:
the review workspace derives it from the policy deadline. A later migration can
add an explicit lifecycle status only if it is needed for the audit trail.

## Source-specific revalidation windows

These are initial, conservative pilot windows. They are review deadlines, not
automatic deletion dates. They must be recalibrated from pilot outcomes before
automatic expiry is enabled.

| Source and confidence | Revalidate after | Warning begins | Rationale |
| --- | ---: | ---: | --- |
| On-road survey, confidence ≥ 0.80 | 90 days | 30 days before due | Direct observation, but road surfaces can change seasonally. |
| On-road survey, confidence < 0.80 | 60 days | 21 days before due | A weaker survey claim needs earlier confirmation. |
| Authoritative agency or maintenance record | 60 days | 21 days before due | The record may lag physical works. |
| OSM tag-based import | 30 days | 14 days before due | A map edit is an indirect signal, not an inspection. |
| Time-sensitive obstruction report | 7 days | 48 hours before due | Closures and obstructions change quickly. |
| Community report | Deferred | N/A | Community reporting is out of scope until candidate-route coverage is proven. |

The deadline is calculated from `verified_at`, not `observed_at`, and can only
be extended by a new review. A source refresh records a new verification; an
on-road revisit creates a new evidence record linked to the prior one. Neither
silently rewrites history.

## Required data and audit trail before automation

Before the first expiry job is shipped, add a revalidation record for every
review action with:

- evidence ID and immutable evidence snapshot/version;
- reviewer user ID, decision, reviewed-at time, and required reviewer notes;
- review method (`source_refresh` or `field_survey`), source timestamp, and
  optional replacement evidence ID;
- policy version, calculated revalidation due date, and any approved override
  reason; and
- the transition to `expired`, its time, and the job/policy version that made
  it happen.

Use a separate `evidence_revalidations` table rather than overwriting
`verified_at` or `valid_until`. Keep `valid_until` as an explicit source or
reviewer constraint; the effective expiry is the earlier of that value and the
policy deadline. Revalidation records and expired/rejected evidence are
retained indefinitely for audit.

## Rollout gates

1. **Instrument only.** Calculate and display due dates, warning bands, and
   evidence age in the admin workspace and route explanations. Do not alter
   routing. Record the reviewer and notes for every manual review.
2. **Warning-only pilot.** For two 30-day review cycles, notify reviewers of
   soon-due and stale evidence. Measure the share reviewed on time, the rate of
   conflicting replacements, and any route-rank changes caused by updates.
3. **Shadow expiry.** Compute which evidence would be excluded, but continue
   routing with it. Compare recommendations and unknown-road fallback rates for
   at least 14 consecutive days.
4. **Approval gate.** Enable automatic expiry only when all are true: at least
   95% of due records were reviewed on time in the two pilot cycles; no
   unresolved audit defects exist; the shadow run causes no unexplained safety
   regression; and a named product and operations owner approve the policy
   version and thresholds.
5. **Controlled enablement.** Expire one source type at a time, beginning with
   OSM imports. Emit an audit event for every transition and provide a
   reviewer-only restore/review action. Roll back to warning-only mode if an
   incident or anomalous unknown-road rate is detected.

## Routing and explanation rules

- Routing considers only **verified**, unexpired evidence. `unverified`,
  `rejected`, and `expired` evidence result in an explicit unknown condition.
- Conflicting active evidence continues to use the newest observation, while
  the explanation cites its condition, source, observed time, and verified
  time.
- During warning-only and shadow phases, explanations label ageing evidence as
  "revalidation due"; after expiry, they must state that no current verified
  evidence is available.
- No background process may mutate evidence status until the rollout gates are
  met and a migration plus tests implement the chosen policy version.

## Current operator practice

Until the rollout begins, an administrator periodically reviews the Nairobi
pilot records in `/admin/evidence`. Approving or rejecting there is deliberate,
permission-checked, and immediately determines whether the record can inform
routing. Use the source link and imported tags before approving an OSM record.
