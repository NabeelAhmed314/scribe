defmodule SocialScribe.AIContentGenerator do
  @moduledoc "Generates content using Google Gemini."

  @behaviour SocialScribe.AIContentGeneratorApi

  alias SocialScribe.Meetings
  alias SocialScribe.Automations

  @gemini_model "gemini-2.0-flash-lite"
  @gemini_api_base_url "https://generativelanguage.googleapis.com/v1beta/models"

  @impl SocialScribe.AIContentGeneratorApi
  def generate_follow_up_email(meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        Based on the following meeting transcript, please draft a concise and professional follow-up email.
        The email should summarize the key discussion points and clearly list any action items assigned, including who is responsible if mentioned.
        Keep the tone friendly and action-oriented.

        #{meeting_prompt}
        """

        call_gemini(prompt)
    end
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_automation(automation, meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        #{Automations.generate_prompt_for_automation(automation)}

        #{meeting_prompt}
        """

        call_gemini(prompt)
    end
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_hubspot_suggestions(meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        You are an AI assistant that extracts contact information updates from meeting transcripts.

        Analyze the following meeting transcript and extract any information that could be used to update a CRM contact record.

        Look for mentions of:
        - Phone numbers (phone, mobilephone)
        - Email addresses (email)
        - Company name (company)
        - Job title/role (jobtitle)
        - Physical address details (address, city, state, zip, country)
        - Website URLs (website)
        - LinkedIn profile (linkedin_url)
        - Twitter handle (twitter_handle)

        IMPORTANT: Only extract information that is EXPLICITLY mentioned in the transcript. Do not infer or guess.

        The transcript includes timestamps in [MM:SS] format at the start of each line.

        Return your response as a JSON array of objects. Each object should have:
        - "field": the CRM field name (use exactly: firstname, lastname, email, phone, mobilephone, company, jobtitle, address, city, state, zip, country, website, linkedin_url, twitter_handle)
        - "value": the extracted value
        - "context": a brief quote of where this was mentioned
        - "timestamp": the timestamp in MM:SS format where this was mentioned

        If no contact information updates are found, return an empty array: []

        Example response format:
        [
          {"field": "phone", "value": "555-123-4567", "context": "John mentioned 'you can reach me at 555-123-4567'", "timestamp": "01:23"},
          {"field": "company", "value": "Acme Corp", "context": "Sarah said she just joined Acme Corp", "timestamp": "05:47"}
        ]

        ONLY return valid JSON, no other text.

        Meeting transcript:
        #{meeting_prompt}
        """

        case call_gemini(prompt) do
          {:ok, response} ->
            parse_hubspot_suggestions(response)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_salesforce_suggestions(meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        You are an AI assistant that extracts contact information updates from meeting transcripts for Salesforce CRM.

        Analyze the following meeting transcript and extract any information that could be used to update a Salesforce Contact record.

        Look for mentions of:
        - Phone numbers (Phone, MobilePhone)
        - Email addresses (Email)
        - Company name (Company - maps to Account.Name in Salesforce)
        - Job title/role (Title)
        - Name components (FirstName, LastName)
        - Physical address details (MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry)

        IMPORTANT: Only extract information that is EXPLICITLY mentioned in the transcript. Do not infer or guess.

        The transcript includes timestamps in [MM:SS] format at the start of each line.

        Return your response as a JSON array of objects. Each object should have:
        - "field": the Salesforce field name (use exactly: FirstName, LastName, Email, Phone, MobilePhone, Title, Company, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry)
        - "value": the extracted value
        - "context": a brief quote of where this was mentioned
        - "timestamp": the timestamp in MM:SS format where this was mentioned

        If no contact information updates are found, return an empty array: []

        Example response format:
        [
          {"field": "Phone", "value": "555-123-4567", "context": "John mentioned 'you can reach me at 555-123-4567'", "timestamp": "01:23"},
          {"field": "Company", "value": "Acme Corp", "context": "Sarah said she just joined Acme Corp", "timestamp": "05:47"},
          {"field": "MailingCity", "value": "San Francisco", "context": "We're based in San Francisco", "timestamp": "12:34"}
        ]

        ONLY return valid JSON, no other text.

        Meeting transcript:
        #{meeting_prompt}
        """

        case call_gemini(prompt) do
          {:ok, response} ->
            parse_salesforce_suggestions(response)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp parse_hubspot_suggestions(response) do
    # Clean up the response - remove markdown code blocks if present
    cleaned =
      response
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, suggestions} when is_list(suggestions) ->
        formatted =
          suggestions
          |> Enum.filter(&is_map/1)
          |> Enum.map(fn s ->
            %{
              field: s["field"],
              value: s["value"],
              context: s["context"],
              timestamp: s["timestamp"]
            }
          end)
          |> Enum.filter(fn s -> s.field != nil and s.value != nil end)

        {:ok, formatted}

      {:ok, _} ->
        {:ok, []}

      {:error, _} ->
        # If JSON parsing fails, return empty suggestions
        {:ok, []}
    end
  end

  defp parse_salesforce_suggestions(response) do
    # Clean up the response - remove markdown code blocks if present
    cleaned =
      response
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, suggestions} when is_list(suggestions) ->
        formatted =
          suggestions
          |> Enum.filter(&is_map/1)
          |> Enum.map(fn s ->
            %{
              field: s["field"],
              value: s["value"],
              context: s["context"],
              timestamp: s["timestamp"]
            }
          end)
          |> Enum.filter(fn s -> s.field != nil and s.value != nil end)

        {:ok, formatted}

      {:ok, _} ->
        {:ok, []}

      {:error, _} ->
        # If JSON parsing fails, return empty suggestions
        {:ok, []}
    end
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_crm_query_response(question, contact_context) do
    prompt = build_crm_query_prompt(question, contact_context)
    call_gemini(prompt)
  end

  defp build_crm_query_prompt(question, context) do
    contacts = context.contacts
    history = Map.get(context, :conversation_history, [])
    meeting_transcripts = Map.get(context, :meeting_transcripts, [])

    contacts_text =
      contacts
      |> Enum.with_index(1)
      |> Enum.map(fn {contact, index} ->
        contact_fields =
          contact
          |> Enum.filter(fn {_key, value} -> value != nil and value != "" end)
          |> Enum.map(fn {key, value} -> "  #{format_field_name(key)}: #{value}" end)
          |> Enum.join("\n")

        "[Contact #{index} - #{contact.source}]\n#{contact_fields}"
      end)
      |> Enum.join("\n\n")

    # Build conversation history text if available
    history_text = build_conversation_history_text(history)

    # Build meeting transcripts text if available
    transcripts_text = build_meeting_transcripts_text(meeting_transcripts)

    """
    You are a helpful CRM assistant. Answer the user's question using the contact information and meeting transcripts provided below.

    #{if history_text != "", do: "Conversation History:\n#{history_text}\n\n"}Contact Information:
    #{contacts_text}

    #{if transcripts_text != "", do: "#{transcripts_text}\n\n"}User Question: #{question}

    Provide a clear, concise answer based on the information above. You may use both the CRM contact information and meeting transcripts to answer questions. If the answer cannot be determined from the provided information, say so politely. Consider the conversation history for context when answering follow-up questions.
    """
  end

  defp build_conversation_history_text([]), do: ""

  defp build_conversation_history_text(history) do
    history
    |> Enum.map(fn msg ->
      role = if msg.type == "user", do: "User", else: "Assistant"
      "#{role}: #{msg.content}"
    end)
    |> Enum.join("\n")
  end

  defp build_meeting_transcripts_text([]), do: ""

  defp build_meeting_transcripts_text(transcripts) do
    transcripts_text =
      transcripts
      |> Enum.with_index(1)
      |> Enum.map(fn {meeting, index} ->
        date_str =
          if meeting.meeting_date do
            Calendar.strftime(meeting.meeting_date, "%Y-%m-%d %H:%M")
          else
            "Unknown date"
          end

        duration_min = div(meeting.meeting_duration || 0, 60)

        transcript_text = meeting.transcript || ""

        transcript_preview =
          if String.length(transcript_text) > 2000 do
            String.slice(transcript_text, 0, 2000) <> "\n[Transcript truncated...]"
          else
            transcript_text
          end

        """
        Meeting #{index}: #{meeting.meeting_title}
        Date: #{date_str}
        Duration: #{duration_min} minutes

        Transcript:
        #{transcript_preview}
        """
      end)
      |> Enum.join("\n\n---\n\n")

    "Meeting Transcripts:\n\n#{transcripts_text}"
  end

  defp format_field_name(:name), do: "Name"
  defp format_field_name(:email), do: "Email"
  defp format_field_name(:phone), do: "Phone"
  defp format_field_name(:mobile), do: "Mobile"
  defp format_field_name(:company), do: "Company"
  defp format_field_name(:job_title), do: "Job Title"
  defp format_field_name(:address), do: "Address"
  defp format_field_name(:city), do: "City"
  defp format_field_name(:state), do: "State"
  defp format_field_name(:zip), do: "ZIP Code"
  defp format_field_name(:country), do: "Country"
  defp format_field_name(:website), do: "Website"
  defp format_field_name(:linkedin), do: "LinkedIn"
  defp format_field_name(:twitter), do: "Twitter"
  defp format_field_name(key) when is_atom(key), do: key |> to_string() |> String.capitalize()
  defp format_field_name(key), do: key

  defp call_gemini(prompt_text) do
    api_key = Application.get_env(:social_scribe, :gemini_api_key)

    if is_nil(api_key) or api_key == "" do
      {:error, {:config_error, "Gemini API key is missing - set GEMINI_API_KEY env var"}}
    else
      path = "/#{@gemini_model}:generateContent?key=#{api_key}"

      payload = %{
        contents: [
          %{
            parts: [%{text: prompt_text}]
          }
        ]
      }

      case Tesla.post(client(), path, payload) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          text_path = [
            "candidates",
            Access.at(0),
            "content",
            "parts",
            Access.at(0),
            "text"
          ]

          case get_in(body, text_path) do
            nil -> {:error, {:parsing_error, "No text content found in Gemini response", body}}
            text_content -> {:ok, text_content}
          end

        {:ok, %Tesla.Env{status: status, body: error_body}} ->
          {:error, {:api_error, status, error_body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end
  end

  defp client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @gemini_api_base_url},
      Tesla.Middleware.JSON
    ])
  end
end
