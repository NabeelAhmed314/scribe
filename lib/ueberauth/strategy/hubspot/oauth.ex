defmodule Ueberauth.Strategy.Hubspot.OAuth do
  @moduledoc """
  OAuth2 for HubSpot.

  Add `client_id` and `client_secret` to your configuration:

      config :ueberauth, Ueberauth.Strategy.Hubspot.OAuth,
        client_id: System.get_env("HUBSPOT_CLIENT_ID"),
        client_secret: System.get_env("HUBSPOT_CLIENT_SECRET")
  """

  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://api.hubapi.com",
    authorize_url: "https://app.hubspot.com/oauth/authorize",
    token_url: "https://api.hubapi.com/oauth/v1/token"
  ]

  @doc """
  Construct a client for requests to HubSpot.

  This will be setup automatically for you in `Ueberauth.Strategy.Hubspot`.

  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)

    json_library = Ueberauth.json_library()

    OAuth2.Client.new(opts)
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  @doc """
  Fetches an access token from the HubSpot token endpoint.
  """
  def get_access_token(params \\ [], opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    # HubSpot requires client_id and client_secret in the body
    params =
      params
      |> Keyword.put(:client_id, config[:client_id])
      |> Keyword.put(:client_secret, config[:client_secret])

    case opts |> client() |> OAuth2.Client.get_token(params) do
      {:ok, %OAuth2.Client{token: %OAuth2.AccessToken{} = token}} ->
        {:ok, token}

      {:ok, %OAuth2.Client{token: nil}} ->
        {:error, {"no_token", "No token returned from HubSpot"}}

      {:error, %OAuth2.Response{body: %{"error" => error, "error_description" => description}}} ->
        {:error, {error, description}}

      {:error, %OAuth2.Response{body: %{"message" => message, "status" => status}}} ->
        {:error, {status, message}}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, {"oauth2_error", to_string(reason)}}
    end
  end

  @doc """
  Fetches token info from HubSpot to get hub_id and user email.
  """
  def get_token_info(access_token) do
    url = "https://api.hubapi.com/oauth/v1/access-tokens/#{access_token}"

    case Tesla.get(http_client(), url) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "Failed to get token info: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp http_client do
    Tesla.client([Tesla.Middleware.JSON])
  end

  # OAuth2.Strategy callbacks

  @impl OAuth2.Strategy
  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @impl OAuth2.Strategy
  def get_token(client, params, headers) do
    client
    |> put_param(:grant_type, "authorization_code")
    |> put_header("Content-Type", "application/x-www-form-urlencoded")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end
