defmodule WaziRouteWeb.PageController do
  use WaziRouteWeb, :controller

  def index(conn, _params) do
    if conn.assigns.current_scope do
      redirect(conn, to: ~p"/dashboard")
    else
      redirect(conn, to: ~p"/discover")
    end
  end

  def home(conn, _params) do
    render(conn, :home)
  end
end
