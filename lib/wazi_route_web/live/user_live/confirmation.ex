defmodule WaziRouteWeb.UserLive.Confirmation do
  use WaziRouteWeb, :live_view

  alias WaziRoute.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_magic_link_token(token) do
      %{confirmed_at: confirmed_at} = user when not is_nil(confirmed_at) ->
        form = to_form(%{"token" => token}, as: "user")

        {:ok, assign(socket, user: user, form: form, trigger_submit: false),
         temporary_assigns: [form: nil]}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Magic link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
