defmodule WaziRoute.Workers.SendMail do
  use Oban.Worker, queue: :send_mail, max_attempts: 3

  alias Swoosh.Email
  alias WaziRoute.Mailer

  @impl Oban.Worker
  def perform(
        %Oban.Job{args: %{"recipient" => recipient, "subject" => subject, "body" => body}} = job
      ) do
    perform(%{
      job
      | args: %{
          "recipient" => recipient,
          "subject" => subject,
          "text_body" => body,
          "html_body" => nil
        }
    })
  end

  def perform(%Oban.Job{
        args: %{
          "recipient" => recipient,
          "subject" => subject,
          "text_body" => text_body,
          "html_body" => html_body
        }
      }) do
    email =
      Email.new(
        to: recipient,
        from:
          Application.get_env(
            :wazi_route,
            :mail_from,
            {"Wazi Route", "noreply@wazi-route.local"}
          ),
        subject: subject,
        text_body: text_body,
        html_body: html_body
      )

    case Mailer.deliver(email) do
      {:ok, _metadata} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def create_mail_job(recipient, subject, text_body, html_body \\ nil) do
    %{
      recipient: recipient,
      subject: subject,
      text_body: text_body,
      html_body: html_body
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
