## Completed: planner and driver setup

1. Origin/destination input, replaceable geocoding and routing providers using `Req`.
2. Up to three candidate routes with distance, duration, and map geometry.
3. Explicit missing-provider-data handling and Ruaka–Loresho coverage tests.
4. Authenticated vehicle profiles: transmission, clearance class, hill-start assistance, and a default vehicle.
5. Authenticated route preferences: rough roads, congested uphill sections, verified conditions, detour budget, and unknown-road tolerance.
6. Time-bounded verified road-condition evidence, explicit unknown-condition handling, and deterministic candidate reranking.
7. On-demand elevation sampling, directional uphill estimates, and a geometry/dataset cache for candidate routes.

## Next: elevation and traffic enrichment

1. Import and validate Nairobi northwest road-condition evidence for the pilot.
2. Integrate traffic with freshness-aware uphill-congestion scoring.
3. Add route explanations that cite the exact evidence used in each recommendation.

Avoid implementing AI or community reports until candidate routes and provider coverage are proven.
