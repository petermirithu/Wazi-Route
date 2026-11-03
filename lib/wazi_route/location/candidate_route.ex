defmodule WaziRoute.Location.CandidateRoute do
  @enforce_keys [:id, :distance_m, :duration_s, :geometry]
  defstruct [
    :id,
    :distance_m,
    :duration_s,
    :geometry,
    :score,
    :comfort_penalty_minutes,
    evidence: %{},
    elevation: %{},
    score_breakdown: %{},
    via: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          distance_m: number(),
          duration_s: number(),
          geometry: map(),
          via: [String.t()],
          score: number() | nil,
          comfort_penalty_minutes: number() | nil,
          evidence: map(),
          elevation: map(),
          score_breakdown: map()
        }
end
