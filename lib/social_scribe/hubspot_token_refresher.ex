defmodule SocialScribe.HubspotTokenRefresher do
  @moduledoc """
  Refreshes HubSpot OAuth tokens.
  """

  @hubspot_token_url "https://api.hubapi.com/oauth/v1/token"

  def client do
    Tesla.client([
      {Tesla.Middleware.FormUrlencoded,
       encode: &Plug.Conn.Query.encode/1, decode: &Plug.Conn.Query.decode/1},
      Tesla.Middleware.JSON
    ])
  end

  @doc """
  Refreshes a HubSpot access token using the refresh token.
  Returns {:ok, response_body} with new access_token, refresh_token, and expires_in.
  """
  def refresh_token(refresh_token_string) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Hubspot.OAuth, [])
    client_id = config[:client_id]
    client_secret = config[:client_secret]

    body = %{
      grant_type: "refresh_token",
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token_string
    }

    case Tesla.post(client(), @hubspot_token_url, body) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        {:error, {status, error_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Refreshes the token for a HubSpot credential and updates it in the database.
  """
  def refresh_credential(credential) do
    alias SocialScribe.Accounts

    case refresh_token(credential.refresh_token) do
      {:ok, response} ->
        # HubSpot returns expires_in in seconds; default to 3600 if missing
        expires_in = response["expires_in"] || 3600
        
        attrs = %{
          token: response["access_token"],
          refresh_token: response["refresh_token"],
          expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
        }

        Accounts.update_user_credential(credential, attrs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Ensures a credential has a valid (non-expired) token.
  Refreshes if expired or about to expire (within 5 minutes).
  """
  def ensure_valid_token(credential) do
    buffer_seconds = 300

    if DateTime.compare(
         credential.expires_at,
         DateTime.add(DateTime.utc_now(), buffer_seconds, :second)
       ) == :lt do
      refresh_credential(credential)
    else
      {:ok, credential}
    end
  end
end
