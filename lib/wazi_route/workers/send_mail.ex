defmodule WaziRoute.Workers.SendMail do
  @moduledoc """
  Delivers transactional email through Mailgun's HTTP API.

  Mailgun is invoked with `curl` rather than SMTP because Render blocks SMTP
  traffic on the ports needed by the previous mail provider.
  """

  use Oban.Worker, queue: :send_mail, max_attempts: 3

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
    case System.cmd("curl", mailgun_curl_args(recipient, subject, text_body, html_body),
           stderr_to_stdout: true
         ) do
      {_response, 0} ->
        :ok

      {response, exit_status} ->
        {:error, {:mailgun_request_failed, exit_status, String.trim(response)}}
    end
  rescue
    error -> {:error, {:mailgun_curl_unavailable, Exception.message(error)}}
  end

  @doc false
  def mailgun_curl_args(recipient, subject, text_body, html_body) do
    mailgun = Application.fetch_env!(:wazi_route, :mailgun)
    {from_name, from_email} = Application.fetch_env!(:wazi_route, :mail_from)

    form_fields = [
      "from=#{from_name} <#{from_email}>",
      "to=#{recipient}",
      "subject=#{subject}",
      "text=#{text_body}"
    ]

    form_fields =
      if is_binary(html_body) and html_body != "" do
        form_fields ++ ["html=#{html_body}"]
      else
        form_fields
      end

    [
      "--silent",
      "--show-error",
      "--fail-with-body",
      "--connect-timeout",
      "10",
      "--max-time",
      "30",
      "--request",
      "POST",
      "--user",
      "api:#{Keyword.fetch!(mailgun, :api_key)}"
    ] ++
      Enum.flat_map(form_fields, &["--form-string", &1]) ++
      [
        "#{String.trim_trailing(Keyword.fetch!(mailgun, :base_url), "/")}/v3/#{Keyword.fetch!(mailgun, :domain)}/messages"
      ]
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
