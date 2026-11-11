## Completed: planner and driver setup

1. Origin/destination input, replaceable geocoding and routing providers using `Req`.
2. Up to three candidate routes with distance, duration, and map geometry.
3. Explicit missing-provider-data handling and Ruaka–Loresho coverage tests.
4. Authenticated vehicle profiles: transmission, clearance class, hill-start assistance, and a default vehicle.
5. Authenticated route preferences: rough roads, congested uphill sections, verified conditions, detour budget, and unknown-road tolerance.
6. Time-bounded verified road-condition evidence, explicit unknown-condition handling, and deterministic candidate reranking.
7. On-demand elevation sampling, directional uphill estimates, and a geometry/dataset cache for candidate routes.
8. On-demand live traffic sampling with a short-lived cache, explicit freshness states, uphill-congestion penalties, and closure filtering.
9. Reviewable, idempotent OSM road-condition imports with preserved source tags and manual approve/reject workflow.
10. Normalized RBAC (`roles`, `permissions`, `role_permissions`, and `user_roles`) with an admin evidence-review workspace for approving or rejecting imported road-condition evidence.
11. Refreshed, validated Nairobi northwest corridor road-condition evidence (Red Hill Road, Red Hill Link Road, Limuru Road, Lower Kabete Road, Waiyaki Way, James Gichuru Road, Loresho Ridge, Kaptagat Road) imported and approved for pilot candidate ranking.
12. Deterministic route explanations citing exact evidence (`WaziRoute.Routing.Explanation`), road conditions, elevation, and live traffic penalties, with an interactive "Why this route was suggested" breakdown in the dashboard.
13. Design an evidence revalidation and expiry policy before enabling automatic expiry.

## Next: evidence collection and explanation
1. 