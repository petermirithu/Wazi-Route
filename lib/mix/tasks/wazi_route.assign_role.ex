defmodule Mix.Tasks.WaziRoute.AssignRole do
  @shortdoc "Assigns a seeded role to an existing user"

  use Mix.Task

  alias WaziRoute.Accounts

  @impl Mix.Task
  def run([email, role_name]) do
    Mix.Task.run("app.start")

    case Accounts.assign_role_by_email(email, role_name) do
      {:ok, user} -> Mix.shell().info("Assigned #{role_name} to #{user.email}.")
      {:error, :not_found} -> Mix.raise("No user exists with email #{inspect(email)}.")
      {:error, :unknown_role} -> Mix.raise("No seeded role exists named #{inspect(role_name)}.")
    end
  end

  def run(_args), do: Mix.raise("Usage: mix wazi_route.assign_role EMAIL ROLE")
end
