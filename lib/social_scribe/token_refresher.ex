defmodule SocialScribe.TokenRefresher do
  @moduledoc """
  Refreshes Google tokens.
  """

  @google_token_url "https://oauth2.googleapis.com/token"

  @behaviour SocialScribe.TokenRefresherApi

  def client do
    middlewares = [
      {Tesla.Middleware.FormUrlencoded,
       encode: &Plug.Conn.Query.encode/1, decode: &Plug.Conn.Query.decode/1},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middlewares)
  end

  def refresh_token(refresh_token_string) do
    client_id = Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id]

    client_secret =
      Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret]

    body = %{
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token_string,
      grant_type: "refresh_token"
    }

    # Use Tesla to make the POST request
    case Tesla.post(client(), @google_token_url, body, opts: [form_urlencoded: true]) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        {:error, {status, error_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
