defmodule WaziRoute.Routing do
  @moduledoc """
  Saved route-comfort preferences for signed-in drivers.
  """

  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Repo
  alias WaziRoute.Routing.Preference

  def get_routing_preferences(%Scope{user: user}) do
    Repo.get_by(Preference, user_id: user.id) || %Preference{user_id: user.id}
  end

  def change_routing_preferences(%Scope{} = scope, attrs \\ %{}) do
    scope
    |> get_routing_preferences()
    |> Preference.changeset(attrs)
  end

  def save_routing_preferences(%Scope{} = scope, attrs) do
    scope
    |> get_routing_preferences()
    |> Preference.changeset(attrs)
    |> Repo.insert_or_update()
  end
end
