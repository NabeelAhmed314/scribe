defmodule Ueberauth.Strategy.Hubspot do
  @moduledoc """
  HubSpot Strategy for Ueberauth.
  """

  use Ueberauth.Strategy,
    uid_field: :hub_id,
    default_scope: "crm.objects.contacts.read crm.objects.contacts.write oauth",
    oauth2_module: Ueberauth.Strategy.Hubspot.OAuth

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles initial request for HubSpot authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    opts =
      [scope: scopes, redirect_uri: callback_url(conn)]
      |> with_optional(:prompt, conn)
      |> with_param(:prompt, conn)
      |> with_state_param(conn)

    redirect!(conn, Ueberauth.Strategy.Hubspot.OAuth.authorize_url!(opts))
  end

  @doc """
  Handles the callback from HubSpot.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    opts = [redirect_uri: callback_url(conn)]

    case Ueberauth.Strategy.Hubspot.OAuth.get_access_token([code: code], opts) do
      {:ok, token} ->
        fetch_user(conn, token)

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw HubSpot response around during the callback.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:hubspot_token, nil)
    |> put_private(:hubspot_user, nil)
  end

  @doc """
  Fetches the uid field from the response.
  """
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string()

    conn.private.hubspot_user[uid_field]
  end

  @doc """
  Includes the credentials from the HubSpot response.
  """
  def credentials(conn) do
    token = conn.private.hubspot_token

    %Credentials{
      expires: true,
      expires_at: token.expires_at,
      scopes: String.split(token.other_params["scope"] || "", " "),
      token: token.access_token,
      refresh_token: token.refresh_token,
      token_type: token.token_type
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.hubspot_user

    %Info{
      email: user["user"],
      name: user["user"]
    }
  end

  @doc """
  Stores the raw information obtained from the HubSpot callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.hubspot_token,
        user: conn.private.hubspot_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :hubspot_token, token)

    case Ueberauth.Strategy.Hubspot.OAuth.get_token_info(token.access_token) do
      {:ok, user} ->
        put_private(conn, :hubspot_user, user)

      {:error, reason} ->
        set_errors!(conn, [error("token_info_error", reason)])
    end
  end

  defp with_param(opts, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(opts, key, value), else: opts
  end

  defp with_optional(opts, key, conn) do
    if option(conn, key), do: Keyword.put(opts, key, option(conn, key)), else: opts
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
