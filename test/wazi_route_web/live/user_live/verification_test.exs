defmodule WaziRouteWeb.UserLive.VerificationTest do
  use WaziRouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import WaziRoute.AccountsFixtures

  alias WaziRoute.Accounts

  describe "email verification" do
    test "verifies a valid OTP and sends the user to login", %{conn: conn} do
      user = unconfirmed_user_fixture()
      path = verification_path(user)
      {:ok, job} = Accounts.deliver_email_verification_code(user, "https://example.com#{path}")
      code = verification_code(job)

      {:ok, lv, _html} = live(conn, path)
      assert has_element?(lv, "#verification-form")

      lv
      |> form("#verification-form", verification: %{code: code})
      |> render_submit()

      assert_redirect(lv, ~p"/users/log-in")
      assert Accounts.get_user!(user.id).confirmed_at
    end

    test "shows remaining attempts for an invalid OTP", %{conn: conn} do
      user = unconfirmed_user_fixture()
      path = verification_path(user)
      {:ok, job} = Accounts.deliver_email_verification_code(user, "https://example.com#{path}")
      wrong_code = if verification_code(job) == "000000", do: "111111", else: "000000"

      {:ok, lv, _html} = live(conn, path)

      html =
        lv
        |> form("#verification-form", verification: %{code: wrong_code})
        |> render_submit()

      assert html =~ "4 attempts remaining"
      assert has_element?(lv, "#verification-error")
    end

    test "enforces the resend cooldown", %{conn: conn} do
      user = unconfirmed_user_fixture()
      path = verification_path(user)
      {:ok, _job} = Accounts.deliver_email_verification_code(user, "https://example.com#{path}")

      {:ok, lv, _html} = live(conn, path)
      html = lv |> element("#resend-verification-code") |> render_click()

      assert html =~ "Please wait 60 seconds"
    end

    test "rejects an invalid verification reference", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/verify-email?token=invalid")
        |> follow_redirect(conn, ~p"/users/register")

      assert html =~ "invalid or has expired"
    end

    test "redirects authenticated users", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:live_redirect, %{to: "/dashboard"}}} =
               live(conn, verification_path(user))
    end
  end

  defp verification_path(user) do
    reference = Phoenix.Token.sign(WaziRouteWeb.Endpoint, "email verification", user.id)
    ~p"/users/verify-email?token=#{reference}"
  end

  defp verification_code(%Oban.Job{args: args}) do
    body = Map.get(args, :text_body) || Map.fetch!(args, "text_body")
    [_, code] = Regex.run(~r/verification code is:\s+(\d{6})/i, body)
    code
  end
end
