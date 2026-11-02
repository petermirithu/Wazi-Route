## Next: build the **basic route-planning vertical slice**

Prioritize the feasibility milestone from `implementation.md`:

1. Origin/destination input.
2. Replaceable geocoding and routing provider interfaces using `Req`.
3. Fetch up to three candidate routes.
4. Display distance, duration, and route geometry on a map.
5. Record missing provider data explicitly.
6. Test the Ruaka–Loresho pilot journey.

Place `/planner` inside the existing authenticated `live_session :require_authenticated_user` in `router.ex`, because route preferences and future vehicle profiles belong to the signed-in user.

After that:

1. Vehicle profiles.
2. Route preferences.
3. Elevation and road-condition evidence.
4. Deterministic scoring.
5. Traffic integration.

Avoid implementing AI or community reports until candidate routes and provider coverage are proven.