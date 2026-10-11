defmodule WaziRoute.Accounts.UserNotifier do
  alias WaziRoute.Accounts.User
  alias WaziRoute.Workers.SendMail

  def deliver_update_email_instructions(user, url) do
    greeting = greeting(user)

    text = """
    #{greeting},

    Use the secure link below to confirm your new Wazi Route email address:

    #{url}

    This link expires in 7 days. If you did not request this change, you can ignore this email.
    """

    deliver_branded_email(
      user.email,
      "Confirm your new Wazi Route email",
      "Confirm your new email",
      "Keep your Wazi Route account details up to date.",
      text,
      action: {"Confirm email address", url},
      greeting: greeting
    )
  end

  def deliver_login_instructions(%User{confirmed_at: nil} = user, _url) do
    {:error, {:email_not_verified, user.email}}
  end

  def deliver_login_instructions(user, url) do
    greeting = greeting(user)

    text = """
    #{greeting},

    Use the secure link below to log in to Wazi Route:

    #{url}

    This link expires in 15 minutes. If you did not request it, you can ignore this email.
    """

    deliver_branded_email(
      user.email,
      "Your Wazi Route login link",
      "Your road back to Wazi",
      "A secure sign-in link is ready for you.",
      text,
      action: {"Log in to Wazi Route", url},
      greeting: greeting
    )
  end

  def deliver_email_verification_code(user, code, verification_url) do
    greeting = greeting(user)

    text = """
    #{greeting},

    Welcome to Wazi Route. Your email verification code is:

    #{code}

    Enter it at #{verification_url}

    This code expires in 10 minutes and can be tried up to 5 times. If you did not create this account, you can ignore this email.
    """

    deliver_branded_email(
      user.email,
      "#{code} is your Wazi Route verification code",
      "Verify your email",
      "One quick step, then your account is ready for the road.",
      text,
      code: code,
      action: {"Enter verification code", verification_url},
      greeting: greeting
    )
  end

  defp deliver_branded_email(recipient, subject, heading, preheader, text_body, options) do
    greeting = Keyword.fetch!(options, :greeting)
    code = Keyword.get(options, :code)
    action = Keyword.get(options, :action)

    html_body = branded_html(greeting, heading, preheader, code, action)
    SendMail.create_mail_job(recipient, subject, text_body, html_body)
  end

  defp branded_html(greeting, heading, preheader, code, action) do
    safe_greeting = escape(greeting)
    safe_heading = escape(heading)
    safe_preheader = escape(preheader)

    code_block =
      if code do
        """
        <div style="margin:28px 0;padding:22px 16px;border:1px solid #dbcdb5;border-radius:14px;background:#f3ead8;text-align:center;">
          <div style="margin-bottom:8px;color:#a94f2d;font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;">Your verification code</div>
          <div style="color:#273f30;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:36px;font-weight:800;letter-spacing:9px;">#{escape(code)}</div>
        </div>
        """
      else
        ""
      end

    action_block =
      case action do
        {label, url} ->
          """
          <div style="margin-top:28px;">
            <a href="#{escape(url)}" style="display:inline-block;border-radius:10px;background:#a94f2d;color:#fffaf0;padding:14px 22px;font-size:14px;font-weight:700;text-decoration:none;">#{escape(label)}</a>
          </div>
          """

        nil ->
          ""
      end

    """
    <!doctype html>
    <html lang="en">
      <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
      <body style="margin:0;background:#f3ead8;color:#24352a;font-family:Arial,sans-serif;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;">#{safe_preheader}</div>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f3ead8;padding:28px 12px;">
          <tr><td align="center">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;overflow:hidden;border:1px solid #dbcdb5;border-radius:20px;background:#fffaf0;">
              <tr><td style="height:6px;background:linear-gradient(90deg,#273f30 0 38%,#e9ad45 38% 62%,#a94f2d 62% 100%);"></td></tr>
              <tr><td style="padding:28px 32px;background:#273f30;color:#fffaf0;">
                <div style="font-size:20px;font-weight:800;letter-spacing:.5px;">WAZI <span style="color:#e9ad45;">ROUTE</span></div>
                <div style="margin-top:5px;color:#d9e1d9;font-size:12px;">Know the road. Choose your way.</div>
              </td></tr>
              <tr><td style="padding:34px 32px 38px;">
                <p style="margin:0 0 12px;color:#a94f2d;font-size:12px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;">#{safe_greeting}</p>
                <h1 style="margin:0;color:#273f30;font-size:30px;line-height:1.2;">#{safe_heading}</h1>
                <p style="margin:14px 0 0;color:#5f6e63;font-size:15px;line-height:1.7;">#{safe_preheader}</p>
                #{code_block}
                #{action_block}
                <p style="margin:30px 0 0;color:#7b877e;font-size:12px;line-height:1.65;">For your security, never share a verification code or login link. Wazi Route will never ask for it by phone or message.</p>
              </td></tr>
              <tr><td style="border-top:1px solid #e7ddcb;padding:20px 32px;color:#7b877e;font-size:11px;line-height:1.6;">Built in Nairobi, for the roads that shape our days.</td></tr>
            </table>
          </td></tr>
        </table>
      </body>
    </html>
    """
  end

  defp greeting(%User{first_name: first_name}) when is_binary(first_name) and first_name != "",
    do: "Hi #{first_name}"

  defp greeting(_user), do: "Hello"

  defp escape(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
