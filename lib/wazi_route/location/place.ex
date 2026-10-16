defmodule WaziRoute.Location.Place do
  @enforce_keys [:id, :label, :latitude, :longitude]
  defstruct [:id, :label, :latitude, :longitude]

  @type t :: %__MODULE__{
          id: String.t(),
          label: String.t(),
          latitude: float(),
          longitude: float()
        }
end
