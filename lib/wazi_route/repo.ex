defmodule WaziRoute.Repo do
  use Ecto.Repo,
    otp_app: :wazi_route,
    adapter: Ecto.Adapters.Postgres
end
