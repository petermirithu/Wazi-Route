defmodule WaziRouteWeb.UserLive.Verification do
  use WaziRouteWeb, :live_view

  alias WaziRoute.Accounts

  @reference_max_age_seconds 24 * 60 * 60

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, push_navigate(socket, to: WaziRouteWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(%{"token" => reference}, _session, socket) do
    with {:ok, user_id} <- verify_reference(reference),
         user when not is_nil(user) <- Accounts.get_user(user_id) do
      if user.confirmed_at do
        {:ok,
         socket
         |> put_flash(:info, "Your email is already verified. You can log in.")
         |> push_navigate(to: ~p"/users/log-in")}
      else
        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:reference, reference)
         |> assign(:verification_error, nil)
         |> assign(:form, to_form(%{"code" => ""}, as: :verification))}
      end
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That verification page is invalid or has expired.")
         |> push_navigate(to: ~p"/users/register")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Open the verification link from your email to continue.")
     |> push_navigate(to: ~p"/users/log-in")}
  end

  @impl true
  def handle_event("verify", %{"verification" => %{"code" => code}}, socket) do
    code = String.trim(code)

    case Accounts.verify_user_email_otp(socket.assigns.user, code) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Email verified. You can now log in to Wazi Route.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, {:invalid_code, 0}} ->
        {:noreply,
         assign(
           socket,
           :verification_error,
           "That code was not correct. Request a new code to continue."
         )}

      {:error, {:invalid_code, remaining}} ->
        {:noreply,
         assign(
           socket,
           :verification_error,
           "That code was not correct. #{remaining} attempts remaining."
         )}

      {:error, :expired} ->
        {:noreply,
         assign(socket, :verification_error, "That code has expired. Request a new one below.")}

      {:error, :locked} ->
        {:noreply,
         assign(
           socket,
           :verification_error,
           "Too many attempts. Request a new code to continue."
         )}

      {:error, :not_found} ->
        {:noreply,
         assign(socket, :verification_error, "No active code was found. Request a new one below.")}
    end
  end

  def handle_event("resend", _params, socket) do
    verification_url = url(~p"/users/verify-email?token=#{socket.assigns.reference}")

    case Accounts.deliver_email_verification_code(socket.assigns.user, verification_url) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> assign(:verification_error, nil)
         |> put_flash(:info, "A new verification code is on its way.")}

      {:error, :too_soon} ->
        {:noreply,
         assign(
           socket,
           :verification_error,
           "Please wait 60 seconds before requesting a new code."
         )}

      {:error, _reason} ->
        {:noreply,
         assign(socket, :verification_error, "We could not send a new code. Please try again.")}
    end
  end

  defp verify_reference(reference) do
    Phoenix.Token.verify(
      WaziRouteWeb.Endpoint,
      "email verification",
      reference,
      max_age: @reference_max_age_seconds
    )
  end
end
