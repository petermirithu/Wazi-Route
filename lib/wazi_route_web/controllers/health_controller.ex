defmodule WaziRouteWeb.HealthController do
  use WaziRouteWeb, :controller

  @doc """
  A dependency-free readiness response used by the installed PWA while a
  Render instance is waking. It intentionally avoids database and provider
  calls: a successful response means the Phoenix application can receive work.
  """
  def show(conn, _params) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> json(%{status: "ready"})
  end
end
