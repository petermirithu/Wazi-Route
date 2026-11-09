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

## Next: evidence collection and explanation

1. Refresh and manually validate Nairobi northwest road-condition evidence before approving it for the pilot.
2. Add route explanations that cite the exact evidence used in each recommendation.
3. Make sure road suggestion is based on route preferences, road conditions etc for best road. with option to view why the suggetsion.
4. Design an evidence revalidation and expiry policy before enabling automatic expiry.

Avoid implementing AI or community reports until candidate routes and provider coverage are proven.