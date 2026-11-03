defmodule WaziRoute.Vehicles do
  @moduledoc """
  User-owned vehicle profiles used when Wazi evaluates route comfort.
  """

  import Ecto.Query, warn: false

  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Repo
  alias WaziRoute.Vehicles.VehicleProfile

  def list_vehicle_profiles(%Scope{user: user}) do
    from(profile in VehicleProfile,
      where: profile.user_id == ^user.id,
      order_by: [desc: profile.is_default, asc: profile.inserted_at]
    )
    |> Repo.all()
  end

  def change_vehicle_profile(%VehicleProfile{} = profile, attrs \\ %{}) do
    VehicleProfile.changeset(profile, attrs)
  end

  def create_vehicle_profile(%Scope{user: user}, attrs) do
    Repo.transaction(fn ->
      is_first_profile? =
        not Repo.exists?(from(profile in VehicleProfile, where: profile.user_id == ^user.id))

      %VehicleProfile{user_id: user.id, is_default: is_first_profile?}
      |> VehicleProfile.changeset(attrs)
      |> Repo.insert()
      |> unwrap_transaction_result()
    end)
    |> normalize_transaction_result()
  end

  def make_default_vehicle_profile(%Scope{user: user}, profile_id) do
    Repo.transaction(fn ->
      case Repo.get_by(VehicleProfile, id: profile_id, user_id: user.id) do
        nil ->
          Repo.rollback(:not_found)

        profile ->
          Repo.update_all(
            from(other in VehicleProfile,
              where: other.user_id == ^user.id and other.id != ^profile.id and other.is_default
            ),
            set: [is_default: false]
          )

          profile
          |> Ecto.Changeset.change(is_default: true)
          |> Repo.update()
          |> unwrap_transaction_result()
      end
    end)
    |> normalize_transaction_result()
  end

  def delete_vehicle_profile(%Scope{user: user}, profile_id) do
    Repo.transaction(fn ->
      case Repo.get_by(VehicleProfile, id: profile_id, user_id: user.id) do
        nil ->
          Repo.rollback(:not_found)

        profile ->
          was_default? = profile.is_default

          with {:ok, deleted_profile} <- Repo.delete(profile),
               :ok <- choose_new_default(user.id, was_default?) do
            deleted_profile
          else
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
    |> normalize_transaction_result()
  end

  defp choose_new_default(_user_id, false), do: :ok

  defp choose_new_default(user_id, true) do
    case Repo.one(
           from(profile in VehicleProfile,
             where: profile.user_id == ^user_id,
             order_by: [asc: profile.inserted_at],
             limit: 1
           )
         ) do
      nil ->
        :ok

      profile ->
        profile |> Ecto.Changeset.change(is_default: true) |> Repo.update() |> result_to_ok()
    end
  end

  defp unwrap_transaction_result({:ok, result}), do: result
  defp unwrap_transaction_result({:error, changeset}), do: Repo.rollback(changeset)

  defp result_to_ok({:ok, _profile}), do: :ok
  defp result_to_ok({:error, changeset}), do: {:error, changeset}

  defp normalize_transaction_result({:ok, result}), do: {:ok, result}
  defp normalize_transaction_result({:error, reason}), do: {:error, reason}
end
