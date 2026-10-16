defmodule WaziRoute.Location.CandidateRoute do
  @enforce_keys [:id, :distance_m, :duration_s, :geometry]
  defstruct [:id, :distance_m, :duration_s, :geometry]

  @type t :: %__MODULE__{
          id: String.t(),
          distance_m: number(),
          duration_s: number(),
          geometry: map()
        }
end
