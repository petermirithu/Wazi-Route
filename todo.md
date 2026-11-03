## Completed: planner and driver setup

1. Origin/destination input, replaceable geocoding and routing providers using `Req`.
2. Up to three candidate routes with distance, duration, and map geometry.
3. Explicit missing-provider-data handling and Ruaka–Loresho coverage tests.
4. Authenticated vehicle profiles: transmission, clearance class, hill-start assistance, and a default vehicle.
5. Authenticated route preferences: rough roads, congested uphill sections, verified conditions, detour budget, and unknown-road tolerance.

## Next: route evidence and scoring

1. Elevation and road-condition evidence for the Nairobi northwest pilot.
2. Directional gradient and road-condition feature extraction.
3. Deterministic scoring using the saved vehicle profile and routing preferences.
4. Traffic integration with freshness-aware uphill-congestion scoring.

Avoid implementing AI or community reports until candidate routes and provider coverage are proven.
