defmodule Mix.Tasks.WaziRoute.GrantAdmin do
  @shortdoc "Grants the admin role to an existing user"

  use Mix.Task

  alias WaziRoute.Accounts

  @impl Mix.Task
  def run([email]) do
    Mix.Task.run("app.start")

    case Accounts.grant_admin_role(email) do
      {:ok, user} -> Mix.shell().info("Granted the admin role to #{user.email}.")
      {:error, :not_found} -> Mix.raise("No user exists with email #{inspect(email)}.")
    end
  end

  def run(_args), do: Mix.raise("Usage: mix wazi_route.grant_admin EMAIL")
end
