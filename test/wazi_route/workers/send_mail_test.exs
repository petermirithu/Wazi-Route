defmodule WaziRoute.Workers.SendMailTest do
  use WaziRoute.DataCase, async: true

  use Oban.Testing, repo: WaziRoute.Repo
  import Swoosh.TestAssertions

  alias WaziRoute.Workers.SendMail

  test "delivers text and HTML email bodies" do
    assert :ok =
             perform_job(SendMail, %{
               recipient: "driver@example.com",
               subject: "Your Wazi code",
               text_body: "Code: 123456",
               html_body: "<strong>123456</strong>"
             })

    assert_email_sent(fn email ->
      assert email.to == [{"", "driver@example.com"}]
      assert email.subject == "Your Wazi code"
      assert email.text_body == "Code: 123456"
      assert email.html_body == "<strong>123456</strong>"
    end)
  end
end
