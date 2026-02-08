defmodule Ueberauth.Strategy.Salesforce.OAuth do
  @moduledoc """
  OAuth2 for Salesforce.

  Add `client_id` and `client_secret` to your configuration:

      config :ueberauth, Ueberauth.Strategy.Salesforce.OAuth,
        client_id: System.get_env("SALESFORCE_CLIENT_ID"),
        client_secret: System.get_env("SALESFORCE_CLIENT_SECRET"),
        domain: System.get_env("SALESFORCE_DOMAIN", "login.salesforce.com")

  For Developer Edition or sandbox orgs, set SALESFORCE_DOMAIN to your instance URL
  (e.g., "orgfarm-a9a2af9849-dev-ed.develop.my.salesforce.com")
  """

  use OAuth2.Strategy

  defp defaults do
    domain = get_domain()

    [
      strategy: __MODULE__,
      site: "https://#{domain}",
      authorize_url: "https://#{domain}/services/oauth2/authorize",
      token_url: "https://#{domain}/services/oauth2/token"
    ]
  end

  defp get_domain do
    config = Application.get_env(:ueberauth, __MODULE__, [])
    config[:domain] || "login.salesforce.com"
  end

  @doc """
  Construct a client for requests to Salesforce.

  This will be setup automatically for you in `Ueberauth.Strategy.Salesforce`.

  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    opts =
      defaults()
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
  Fetches an access token from the Salesforce token endpoint.
  """
  def get_access_token(params \\ [], opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    # Get code_verifier from opts if present (PKCE)
    code_verifier = opts[:code_verifier]

    # Salesforce requires client_id and client_secret in the body
    params =
      params
      |> Keyword.put(:client_id, config[:client_id])
      |> Keyword.put(:client_secret, config[:client_secret])

    # Add code_verifier for PKCE if present
    params =
      if code_verifier do
        Keyword.put(params, :code_verifier, code_verifier)
      else
        params
      end

    case opts |> client() |> OAuth2.Client.get_token(params) do
      {:ok, %OAuth2.Client{token: %OAuth2.AccessToken{} = token}} ->
        {:ok, token}

      {:ok, %OAuth2.Client{token: nil}} ->
        {:error, {"no_token", "No token returned from Salesforce"}}

      {:error, %OAuth2.Response{body: %{"error" => error, "error_description" => description}}} ->
        {:error, {error, description}}

      {:error, %OAuth2.Response{body: %{"message" => message, "status" => status}}} ->
        {:error, {status, message}}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, {"oauth2_error", to_string(reason)}}
    end
  end

  @doc """
  Fetches user identity from Salesforce using the identity URL from token response.
  """
  def get_user_info(access_token, identity_url) do
    case Tesla.get(http_client(), identity_url, headers: [{"Authorization", "Bearer #{access_token}"}]) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        user_info = %{
          "user_id" => body["user_id"],
          "email" => body["email"],
          "username" => body["username"],
          "organization_id" => body["organization_id"]
        }
        {:ok, user_info}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "Failed to get user info: #{status} - #{inspect(body)}"}

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
