defmodule SocialScribe.CalendarSyncronizer do
  @moduledoc """
  Fetches and syncs Google Calendar events.
  """

  require Logger

  alias SocialScribe.GoogleCalendarApi
  alias SocialScribe.Calendar
  alias SocialScribe.Accounts
  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.TokenRefresherApi

  @doc """
  Syncs events for a user.

  Currently, only works for the primary calendar and for meeting links that are either on the hangoutLink or location field.

  #TODO: Add support for syncing only since the last sync time and record sync attempts
  """
  def sync_events_for_user(user) do
    user
    |> Accounts.list_user_credentials(provider: "google")
    |> Task.async_stream(&fetch_and_sync_for_credential/1, ordered: false, on_timeout: :kill_task)
    |> Stream.run()

    {:ok, :sync_complete}
  end

  defp fetch_and_sync_for_credential(%UserCredential{} = credential) do
    with {:ok, token} <- ensure_valid_token(credential),
         {:ok, %{"items" => items}} <-
           GoogleCalendarApi.list_events(
             token,
             DateTime.utc_now() |> Timex.beginning_of_day() |> Timex.shift(days: -1),
             DateTime.utc_now() |> Timex.end_of_day() |> Timex.shift(days: 7),
             "primary"
           ),
         :ok <- sync_items(items, credential.user_id, credential.id) do
      :ok
    else
      {:error, reason} ->
        # Log errors but don't crash the sync for other accounts
        Logger.error("Failed to sync credential #{credential.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_valid_token(%UserCredential{} = credential) do
    if DateTime.compare(credential.expires_at || DateTime.utc_now(), DateTime.utc_now()) == :lt do
      case TokenRefresherApi.refresh_token(credential.refresh_token) do
        {:ok, new_token_data} ->
          {:ok, updated_credential} =
            Accounts.update_credential_tokens(credential, new_token_data)

          {:ok, updated_credential.token}

        {:error, reason} ->
          {:error, {:refresh_failed, reason}}
      end
    else
      {:ok, credential.token}
    end
  end

  defp sync_items(items, user_id, credential_id) do
    Enum.each(items, fn item ->
      # We only sync meetings that have a zoom or google meet link for now
      if String.contains?(Map.get(item, "location", ""), ".zoom.") || Map.get(item, "hangoutLink") do
        Calendar.create_or_update_calendar_event(parse_google_event(item, user_id, credential_id))
      end
    end)

    :ok
  end

  defp parse_google_event(item, user_id, credential_id) do
    start_time_str = Map.get(item["start"], "dateTime", Map.get(item["start"], "date"))
    end_time_str = Map.get(item["end"], "dateTime", Map.get(item["end"], "date"))

    %{
      google_event_id: item["id"],
      summary: Map.get(item, "summary", "No Title"),
      description: Map.get(item, "description"),
      location: Map.get(item, "location"),
      html_link: Map.get(item, "htmlLink"),
      hangout_link: Map.get(item, "hangoutLink", Map.get(item, "location")),
      status: Map.get(item, "status"),
      start_time: to_utc_datetime(start_time_str),
      end_time: to_utc_datetime(end_time_str),
      user_id: user_id,
      user_credential_id: credential_id
    }
  end

  defp to_utc_datetime(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, datetime, _offset} ->
        datetime

      _ ->
        nil
    end
  end
end
