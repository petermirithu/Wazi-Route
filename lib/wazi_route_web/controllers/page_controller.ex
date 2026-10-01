defmodule WaziRouteWeb.PageController do
  use WaziRouteWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
