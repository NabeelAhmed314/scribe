defmodule SocialScribe.SalesforceApi do
  @moduledoc """
  Salesforce CRM API client for contacts operations.
  Implements automatic token refresh on 401/expired token errors.
  """

  @behaviour SocialScribe.SalesforceApiBehaviour

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.SalesforceTokenRefresher

  require Logger

  @api_version "v59.0"

  @contact_properties [
    "Id", "FirstName", "LastName", "Email", "Phone", "MobilePhone",
    "Title", "AccountId", "Account.Name", "MailingStreet",
    "MailingCity", "MailingState", "MailingPostalCode", "MailingCountry"
  ]

  defp client(access_token, instance_url) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, instance_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{access_token}"},
         {"Content-Type", "application/json"}
       ]}
    ])
  end

  @doc """
  Searches for contacts by query string using SOSL (Salesforce Object Search Language).
  Returns up to 10 matching contacts with basic properties.
  Automatically refreshes token on 401/expired errors and retries once.
  """
  def search_contacts(%UserCredential{} = credential, query) when is_binary(query) do
    if is_nil(credential.instance_url) do
      Logger.error("Salesforce API error: instance_url is required but missing")
      {:error, :missing_instance_url}
    else
      with_token_refresh(credential, fn cred ->
        fields = Enum.join(@contact_properties, ", ")
        # Build SOSL query: FIND {search_term} IN ALL FIELDS RETURNING Contact(fields)
        sosl_query = "FIND {#{escape_sosl(query)}} IN ALL FIELDS RETURNING Contact(#{fields})"
        encoded_query = URI.encode_query(%{"q" => sosl_query})

        case Tesla.get(
               client(cred.token, cred.instance_url),
               "/services/data/#{@api_version}/search?#{encoded_query}"
             ) do
          {:ok, %Tesla.Env{status: 200, body: %{"searchRecords" => results}}} ->
            contacts = Enum.map(results, &format_contact/1)
            {:ok, contacts}

          {:ok, %Tesla.Env{status: 200, body: %{}}} ->
            # No search results
            {:ok, []}

          {:ok, %Tesla.Env{status: status, body: body}} ->
            {:error, {:api_error, status, body}}

          {:error, reason} ->
            {:error, {:http_error, reason}}
        end
      end)
    end
  end

  @doc """
  Gets a single contact by ID with all properties.
  Automatically refreshes token on 401/expired errors and retries once.
  """
  def get_contact(%UserCredential{} = credential, contact_id) do
    if is_nil(credential.instance_url) do
      Logger.error("Salesforce API error: instance_url is required but missing")
      {:error, :missing_instance_url}
    else
      with_token_refresh(credential, fn cred ->
        fields = Enum.join(@contact_properties, ",")
        url = "/services/data/#{@api_version}/sobjects/Contact/#{contact_id}?fields=#{fields}"

        case Tesla.get(client(cred.token, cred.instance_url), url) do
          {:ok, %Tesla.Env{status: 200, body: body}} ->
            {:ok, format_contact(body)}

          {:ok, %Tesla.Env{status: 404, body: _body}} ->
            {:error, :not_found}

          {:ok, %Tesla.Env{status: status, body: body}} ->
            {:error, {:api_error, status, body}}

          {:error, reason} ->
            {:error, {:http_error, reason}}
        end
      end)
    end
  end

  @doc """
  Updates a contact's properties.
  `updates` should be a map of property names to new values.
  Salesforce uses flat structure (not nested "properties" like HubSpot).
  Automatically refreshes token on 401/expired errors and retries once.
  """
  def update_contact(%UserCredential{} = credential, contact_id, updates)
      when is_map(updates) do
    if is_nil(credential.instance_url) do
      Logger.error("Salesforce API error: instance_url is required but missing")
      {:error, :missing_instance_url}
    else
      with_token_refresh(credential, fn cred ->
        # Salesforce expects flat structure, not nested properties
        body = updates

        case Tesla.patch(
               client(cred.token, cred.instance_url),
               "/services/data/#{@api_version}/sobjects/Contact/#{contact_id}",
               body
             ) do
          {:ok, %Tesla.Env{status: 204, body: _body}} ->
            # Salesforce returns 204 No Content on success, fetch updated contact
            get_contact(cred, contact_id)

          {:ok, %Tesla.Env{status: 404, body: _body}} ->
            {:error, :not_found}

          {:ok, %Tesla.Env{status: status, body: body}} ->
            {:error, {:api_error, status, body}}

          {:error, reason} ->
            {:error, {:http_error, reason}}
        end
      end)
    end
  end

  @doc """
  Batch updates multiple properties on a contact.
  This is a convenience wrapper around update_contact/3.
  """
  def apply_updates(%UserCredential{} = credential, contact_id, updates_list)
      when is_list(updates_list) do
    updates_map =
      updates_list
      |> Enum.filter(fn update -> update[:apply] == true end)
      |> Enum.reduce(%{}, fn update, acc ->
        Map.put(acc, update.field, update.new_value)
      end)

    if map_size(updates_map) > 0 do
      update_contact(credential, contact_id, updates_map)
    else
      {:ok, :no_updates}
    end
  end

  # Format a Salesforce contact response into a cleaner structure
  # Maps Salesforce PascalCase fields to lowercase atom keys
  defp format_contact(%{} = contact) do
    %{
      id: contact["Id"] || contact["id"],
      firstname: contact["FirstName"],
      lastname: contact["LastName"],
      email: contact["Email"],
      phone: contact["Phone"],
      mobilephone: contact["MobilePhone"],
      jobtitle: contact["Title"],
      company: get_in(contact, ["Account", "Name"]),
      address: contact["MailingStreet"],
      city: contact["MailingCity"],
      state: contact["MailingState"],
      zip: contact["MailingPostalCode"],
      country: contact["MailingCountry"],
      display_name: format_display_name(contact)
    }
  end

  defp format_contact(_), do: nil

  defp format_display_name(contact) do
    firstname = contact["FirstName"] || ""
    lastname = contact["LastName"] || ""
    email = contact["Email"] || ""

    name = String.trim("#{firstname} #{lastname}")

    if name == "" do
      email
    else
      name
    end
  end

  # Escape special characters in SOSL search queries
  # Salesforce SOSL uses backslash to escape special characters
  defp escape_sosl(query) do
    query
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("'", "\\'")
    |> String.replace("?", "\\?")
    |> String.replace("&", "\\&")
    |> String.replace("|", "\\|")
    |> String.replace("!", "\\!")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
    |> String.replace("^", "\\^")
    |> String.replace("~", "\\~")
    |> String.replace("*", "\\*")
    |> String.replace(":", "\\:")
  end

  # Wrapper that handles token refresh on auth errors
  # Tries the API call, and if it fails with 401 or INVALID_SESSION_ID, refreshes token and retries once
  defp with_token_refresh(%UserCredential{} = credential, api_call) do
    case SalesforceTokenRefresher.ensure_valid_token(credential) do
      {:ok, credential} ->
        case api_call.(credential) do
          {:error, {:api_error, status, body}} when status in [401, 403] ->
            if is_token_error?(body) do
              Logger.info("Salesforce token expired, refreshing and retrying...")
              retry_with_fresh_token(credential, api_call)
            else
              Logger.error("Salesforce API error: #{status} - #{inspect(body)}")
              {:error, {:api_error, status, body}}
            end

          other ->
            other
        end

      {:error, reason} = error ->
        Logger.error("Failed to ensure valid Salesforce token: #{inspect(reason)}")
        error
    end
  end

  defp retry_with_fresh_token(credential, api_call) do
    case SalesforceTokenRefresher.refresh_credential(credential) do
      {:ok, refreshed_credential} ->
        case api_call.(refreshed_credential) do
          {:error, {:api_error, status, body}} ->
            Logger.error("Salesforce API error after refresh: #{status} - #{inspect(body)}")
            {:error, {:api_error, status, body}}

          {:error, {:http_error, reason}} ->
            Logger.error("Salesforce HTTP error after refresh: #{inspect(reason)}")
            {:error, {:http_error, reason}}

          success ->
            success
        end

      {:error, refresh_error} ->
        Logger.error("Failed to refresh Salesforce token: #{inspect(refresh_error)}")
        {:error, {:token_refresh_failed, refresh_error}}
    end
  end

  defp is_token_error?(%{"errorCode" => "INVALID_SESSION_ID"}), do: true
  defp is_token_error?(%{"errorCode" => "INVALID_AUTH"}), do: true

  # Handle lists of error maps (common Salesforce error payload shape)
  defp is_token_error?(errors) when is_list(errors) do
    Enum.any?(errors, fn error ->
      is_token_error?(error)
    end)
  end

  defp is_token_error?(body) when is_binary(body) do
    downcased = String.downcase(body)
    String.contains?(downcased, ["token", "expired", "unauthorized", "session", "invalid"])
  end
  defp is_token_error?(%{"message" => msg}) when is_binary(msg) do
    String.contains?(String.downcase(msg), ["token", "expired", "unauthorized", "session", "invalid"])
  end
  defp is_token_error?(_), do: false
end
