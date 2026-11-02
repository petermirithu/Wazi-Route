defmodule WaziRoute.Workers.SendMailTest do
  use WaziRoute.DataCase, async: true

  use Oban.Testing, repo: WaziRoute.Repo
  alias WaziRoute.Workers.SendMail

  test "builds a Mailgun HTTP request with text and HTML bodies" do
    args =
      SendMail.mailgun_curl_args(
        "driver@example.com",
        "Your Wazi code",
        "Code: 123456",
        "<strong>123456</strong>"
      )

    assert "--user" in args
    assert "api:test-api-key" in args
    assert "--form-string" in args
    assert "to=driver@example.com" in args
    assert "subject=Your Wazi code" in args
    assert "text=Code: 123456" in args
    assert "html=<strong>123456</strong>" in args
    assert List.last(args) == "https://api.mailgun.net/v3/example.mailgun.org/messages"
  end
end
