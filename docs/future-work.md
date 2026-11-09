# Deferred product work

## Evidence revalidation and expiry

OSM evidence is currently retained after import and may remain approved. We do
not treat its OSM timestamp as a forced expiry date, because it represents a map
edit timestamp rather than a confirmed road inspection date.

Before enabling evidence expiry, add a reviewed revalidation workflow that:

1. records who reviewed an item and their notes;
2. distinguishes a source update from an on-road survey;
3. applies source-specific validity periods only after calibration;
4. warns administrators before evidence becomes stale;
5. keeps expired and rejected records for audit while excluding them from routing;
6. makes route explanations disclose when evidence was last verified.

Until that work is complete, administrators must periodically review pilot
evidence in the admin workspace rather than relying on automatic expiration.
