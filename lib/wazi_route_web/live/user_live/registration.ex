defmodule WaziRouteWeb.UserLive.Registration do
  use WaziRouteWeb, :live_view

  alias WaziRoute.Accounts
  alias WaziRoute.Accounts.User

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: WaziRouteWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset =
      Accounts.change_user_registration(%User{}, %{},
        validate_unique: false,
        hash_password: false
      )

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        reference = verification_reference(user)
        verification_path = ~p"/users/verify-email?token=#{reference}"
        verification_url = url(~p"/users/verify-email?token=#{reference}")

        case Accounts.deliver_email_verification_code(user, verification_url) do
          {:ok, _job} ->
            {:noreply,
             socket
             |> put_flash(:info, "We sent a 6-digit verification code to #{user.email}.")
             |> push_navigate(to: verification_path)}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "Your account was created, but we could not send the verification email. Please try again shortly."
             )
             |> push_navigate(to: verification_path)}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_registration(%User{}, user_params,
        validate_unique: false,
        hash_password: false
      )

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp verification_reference(user) do
    Phoenix.Token.sign(WaziRouteWeb.Endpoint, "email verification", user.id)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
