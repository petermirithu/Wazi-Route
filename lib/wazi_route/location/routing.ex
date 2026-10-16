defmodule WaziRoute.Location.Routing do
  alias WaziRoute.Location.CandidateRoute

  @type coordinates :: {latitude :: float(), longitude :: float()}

  @callback routes(origin :: coordinates(), destination :: coordinates(), options :: keyword()) ::
              {:ok, [CandidateRoute.t()]} | {:error, term()}
end
