defmodule WaziRoute.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query
  alias WaziRoute.Accounts.UserToken

  @hash_algorithm :sha256
  @rand_size 32

  @magic_link_validity_in_minutes 15
  @email_verification_validity_in_minutes 10
  @change_email_validity_in_days 7
  @session_validity_in_days 14
  @email_verification_context "verify_email"

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :attempts, :integer, default: 0
    field :authenticated_at, :utc_datetime
    belongs_to :user, WaziRoute.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix's default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    dt = user.authenticated_at || DateTime.utc_now(:second)
    {token, %UserToken{token: token, context: "session", user_id: user.id, authenticated_at: dt}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any, along with the token's creation time.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: {%{user | authenticated_at: token.authenticated_at}, token.inserted_at}

    {:ok, query}
  end

  @doc """
  Builds a token and its hash to be delivered to the user's email.

  The non-hashed token is sent to the user email while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the user changes
  their email in the system, the tokens sent to the previous email are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.
  """
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  def build_email_verification_code(user) do
    code = generate_six_digit_code()

    {code,
     %UserToken{
       token: hash_email_verification_code(user.id, code),
       context: @email_verification_context,
       sent_to: user.email,
       user_id: user.id
     }}
  end

  def email_verification_token_query(user_id) do
    from token in UserToken,
      where: token.user_id == ^user_id and token.context == @email_verification_context,
      order_by: [desc: token.inserted_at],
      limit: 1
  end

  def valid_email_verification_code?(%UserToken{user_id: user_id, token: token}, code)
      when is_binary(code) do
    candidate = hash_email_verification_code(user_id, code)
    byte_size(candidate) == byte_size(token) and Plug.Crypto.secure_compare(candidate, token)
  end

  def valid_email_verification_code?(_token, _code), do: false

  def email_verification_expired?(%UserToken{inserted_at: inserted_at}) do
    DateTime.before?(
      inserted_at,
      DateTime.utc_now(:second) |> DateTime.add(-@email_verification_validity_in_minutes, :minute)
    )
  end

  def email_verification_context, do: @email_verification_context

  defp hash_email_verification_code(user_id, code) do
    :crypto.hash(@hash_algorithm, "#{user_id}:#{code}")
  end

  defp generate_six_digit_code do
    <<value::unsigned-32>> = :crypto.strong_rand_bytes(4)
    Integer.to_string(rem(value, 1_000_000)) |> String.pad_leading(6, "0")
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  If found, the query returns a tuple of the form `{user, token}`.

  The given token is valid if it matches its hashed counterpart in the
  database. This function also checks whether the token has expired. The context
  of a magic link token is always "login".
  """
  def verify_magic_link_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "login"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^@magic_link_validity_in_minutes, "minute"),
            where: token.sent_to == user.email,
            select: {user, token}

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user_token found by the token, if any.

  This is used to validate requests to change the user
  email.
  The given token is valid if it matches its hashed counterpart in the
  database and if it has not expired (after @change_email_validity_in_days).
  The context must always start with "change:".
  """
  def verify_change_email_token_query(token, "change:" <> _ = context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  defp by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end
end
