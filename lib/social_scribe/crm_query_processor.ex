defmodule SocialScribe.CrmQueryProcessor do
  @moduledoc """
  Processes CRM queries by retrieving contact data and generating AI responses.
  Orchestrates between CRM APIs (HubSpot, Salesforce) and AI content generation.
  """

  alias SocialScribe.HubspotApiBehaviour, as: HubspotApi
  alias SocialScribe.SalesforceApiBehaviour, as: SalesforceApi
  alias SocialScribe.AIContentGeneratorApi
  alias SocialScribe.Accounts
  alias SocialScribe.Meetings

  require Logger

  @doc """
  Processes a user query about selected contacts.

  Retrieves full contact details from CRMs and generates an AI response.

  ## Parameters
    - user: The current user struct
    - message_text: The user's question
    - selected_contacts: List of selected contacts with id and source
    - conversation_history: List of previous chat messages for context (optional)

  ## Returns
    - {:ok, ai_response} on success
    - {:error, reason} on failure
  """
  def process_query(user, message_text, selected_contacts, conversation_history \\ []) do
    # Get user credentials
    hubspot_credential = Accounts.get_user_hubspot_credential(user.id)
    salesforce_credential = Accounts.get_user_salesforce_credential(user.id)

    # Retrieve full contact details from CRMs
    contact_details =
      selected_contacts
      |> Task.async_stream(
        fn contact ->
          # Handle both atom and string keys
          source = get_field(contact, :source)

          case source do
            "hubspot" ->
              if hubspot_credential do
                retrieve_contact_details(hubspot_credential, contact)
              else
                {:error, :no_hubspot_credential}
              end

            "salesforce" ->
              if salesforce_credential do
                retrieve_contact_details(salesforce_credential, contact)
              else
                {:error, :no_salesforce_credential}
              end

            _ ->
              {:error, :unknown_source}
          end
        end,
        max_concurrency: 5,
        timeout: 10_000
      )
      |> Enum.reduce([], fn {:ok, result}, acc ->
        case result do
          {:ok, contact_data} -> [contact_data | acc]
          {:error, _reason} -> acc
        end
      end)
      |> Enum.reverse()

    if Enum.empty?(contact_details) do
      {:error, :no_contact_data_available}
    else
      # Fetch meetings with transcripts for these contacts
      contact_emails = Enum.map(contact_details, & &1.email)
      meetings = Meetings.get_meetings_for_contacts(user, contact_emails)
      meeting_transcripts = extract_meeting_transcripts(meetings)

      # Build contact context map with conversation history and meeting data
      contact_context = %{
        contacts: contact_details,
        question: message_text,
        conversation_history: conversation_history,
        meetings: meetings,
        meeting_transcripts: meeting_transcripts
      }

      # Generate AI response
      case AIContentGeneratorApi.generate_crm_query_response(message_text, contact_context) do
        {:ok, response} ->
          {:ok, response}

        {:error, reason} ->
          Logger.error("Failed to generate CRM query response: #{inspect(reason)}")
          {:error, :ai_generation_failed}
      end
    end
  end

  @doc """
  Retrieves full contact details from the appropriate CRM.

  ## Parameters
    - credential: The user's CRM credential
    - contact: Contact struct with id and source

  ## Returns
    - {:ok, contact_data} on success
    - {:error, reason} on failure
  """
  def retrieve_contact_details(credential, contact) do
    # Handle both atom and string keys
    source = get_field(contact, :source)
    contact_id = get_field(contact, :id)

    case source do
      "hubspot" ->
        case HubspotApi.get_contact(credential, contact_id) do
          {:ok, contact_data} ->
            {:ok, format_hubspot_contact(contact_data)}

          {:error, reason} ->
            Logger.warning("Failed to retrieve HubSpot contact #{contact_id}: #{inspect(reason)}")
            {:error, reason}
        end

      "salesforce" ->
        case SalesforceApi.get_contact(credential, contact_id) do
          {:ok, contact_data} ->
            {:ok, format_salesforce_contact(contact_data)}

          {:error, reason} ->
            Logger.warning(
              "Failed to retrieve Salesforce contact #{contact_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      _ ->
        {:error, :unknown_source}
    end
  end

  # Format HubSpot contact data for AI context
  defp format_hubspot_contact(contact) do
    # Handle both atom and string keys
    firstname = contact[:firstname] || contact["firstname"] || ""
    lastname = contact[:lastname] || contact["lastname"] || ""
    display_name = contact[:display_name] || contact["display_name"] || ""

    name =
      if display_name != "", do: display_name, else: "#{firstname} #{lastname}" |> String.trim()

    %{
      source: "HubSpot",
      id: contact[:id] || contact["id"],
      name: name,
      email: contact[:email] || contact["email"],
      phone: contact[:phone] || contact["phone"],
      mobile: contact[:mobilephone] || contact["mobilephone"],
      company: contact[:company] || contact["company"],
      job_title: contact[:jobtitle] || contact["jobtitle"],
      address: contact[:address] || contact["address"],
      city: contact[:city] || contact["city"],
      state: contact[:state] || contact["state"],
      zip: contact[:zip] || contact["zip"],
      country: contact[:country] || contact["country"],
      website: contact[:website] || contact["website"],
      linkedin: contact[:linkedin_url] || contact["linkedin_url"],
      twitter: contact[:twitter_handle] || contact["twitter_handle"]
    }
  end

  # Format Salesforce contact data for AI context
  defp format_salesforce_contact(contact) do
    # Handle both atom and string keys safely with defaults
    firstname = contact[:firstname] || contact["firstname"] || ""
    lastname = contact[:lastname] || contact["lastname"] || ""
    display_name = contact[:display_name] || contact["display_name"] || ""

    name =
      if display_name != "", do: display_name, else: "#{firstname} #{lastname}" |> String.trim()

    %{
      source: "Salesforce",
      id: contact[:id] || contact["id"],
      name: name,
      email: contact[:email] || contact["email"],
      phone: contact[:phone] || contact["phone"],
      mobile: contact[:mobilephone] || contact["mobilephone"],
      company: contact[:company] || contact["company"],
      job_title: contact[:jobtitle] || contact["jobtitle"],
      address: contact[:address] || contact["address"],
      city: contact[:city] || contact["city"],
      state: contact[:state] || contact["state"],
      zip: contact[:zip] || contact["zip"],
      country: contact[:country] || contact["country"]
    }
  end

  # Helper to get a field from a map with either atom or string keys
  defp get_field(map, key) when is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, to_string(key))
    end
  end

  # Extract formatted transcript text from meetings
  defp extract_meeting_transcripts(meetings) do
    meetings
    |> Enum.filter(fn m ->
      m.meeting_transcript != nil and
        m.meeting_transcript.content != nil
    end)
    |> Enum.map(fn meeting ->
      transcript_content = meeting.meeting_transcript.content || %{}
      transcript_data = transcript_content["data"] || []

      formatted_transcript =
        transcript_data
        |> Enum.map_join("\n", fn segment ->
          speaker = Map.get(segment, "speaker", "Unknown Speaker")
          words = Map.get(segment, "words", [])
          text = Enum.map_join(words, " ", &Map.get(&1, "text", ""))
          "#{speaker}: #{text}"
        end)

      %{
        meeting_title: meeting.title,
        meeting_date: meeting.recorded_at,
        meeting_duration: meeting.duration_seconds,
        transcript: formatted_transcript
      }
    end)
  end
end
