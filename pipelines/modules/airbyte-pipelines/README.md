# airbyte-pipelines module

Reusable module that manages multiple Airbyte pipelines from a single `pipelines` map.

It creates all sources, destinations, and connections directly with `for_each` and exposes aggregated outputs:

- `pipeline_ids`
- `enabled_pipelines`
- `failed_validation_pipelines`
