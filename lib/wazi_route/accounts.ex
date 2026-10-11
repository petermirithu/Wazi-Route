defmodule WaziRoute.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias WaziRoute.Repo

  alias WaziRoute.Accounts.{Scope, User, UserToken, UserNotifier}

  ## Database getters
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)

    cond do
      user && user.confirmed_at && User.valid_password?(user, password) ->
        user

      user && user.confirmed_at ->
        nil

      true ->
        User.valid_password?(nil, password)
        nil
    end
  end

  def get_user!(id), do: Repo.get!(User, id)
  def get_user(id), do: Repo.get(User, id)

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end

  def change_user_profile(%Scope{user: user}, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  def update_user_profile(%Scope{user: user}, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @email_verification_max_attempts 5
  @email_verification_resend_cooldown_seconds 60

  def deliver_email_verification_code(%User{} = user, verification_url) do
    case create_email_verification_code(user) do
      {:ok, code} -> UserNotifier.deliver_email_verification_code(user, code, verification_url)
      error -> error
    end
  end

  def verify_user_email_otp(%User{confirmed_at: confirmed_at} = user, _code)
      when not is_nil(confirmed_at),
      do: {:ok, user}

  def verify_user_email_otp(%User{} = user, code) when is_binary(code) do
    Repo.transaction(fn ->
      token =
        user.id
        |> UserToken.email_verification_token_query()
        |> lock("FOR UPDATE")
        |> Repo.one()

      cond do
        is_nil(token) ->
          {:error, :not_found}

        UserToken.email_verification_expired?(token) ->
          {:error, :expired}

        token.attempts >= @email_verification_max_attempts ->
          {:error, :locked}

        UserToken.valid_email_verification_code?(token, code) ->
          {:ok, confirmed_user} = Repo.update(User.confirm_changeset(user))

          Repo.delete_all(
            from(t in UserToken,
              where:
                t.user_id == ^user.id and
                  t.context == ^UserToken.email_verification_context()
            )
          )

          {:ok, confirmed_user}

        true ->
          attempts = token.attempts + 1

          {1, nil} =
            Repo.update_all(from(t in UserToken, where: t.id == ^token.id),
              set: [attempts: attempts]
            )

          {:error, {:invalid_code, max(@email_verification_max_attempts - attempts, 0)}}
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  def verification_resend_available?(%User{} = user) do
    case Repo.one(UserToken.email_verification_token_query(user.id)) do
      nil ->
        true

      token ->
        DateTime.diff(DateTime.utc_now(:second), token.inserted_at, :second) >=
          @email_verification_resend_cooldown_seconds
    end
  end

  defp create_email_verification_code(%User{} = user) do
    Repo.transaction(fn ->
      Repo.one!(from(u in User, where: u.id == ^user.id, lock: "FOR UPDATE"))
      current_token = Repo.one(UserToken.email_verification_token_query(user.id))

      if current_token &&
           DateTime.diff(DateTime.utc_now(:second), current_token.inserted_at, :second) <
             @email_verification_resend_cooldown_seconds do
        {:error, :too_soon}
      else
        Repo.delete_all(
          from(t in UserToken,
            where: t.user_id == ^user.id and t.context == ^UserToken.email_verification_context()
          )
        )

        {code, token} = UserToken.build_email_verification_code(user)
        {:ok, _token} = Repo.insert(token)
        {:ok, code}
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  ## Profile

  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  def login_user_by_magic_link(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {%User{confirmed_at: confirmed_at} = user, user_token} when not is_nil(confirmed_at) <-
           Repo.one(query) do
      Repo.delete!(user_token)
      {:ok, {user, []}}
    else
      {%User{confirmed_at: nil}, _token} -> {:error, :unconfirmed}
      _ -> {:error, :not_found}
    end
  end

  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper
  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
