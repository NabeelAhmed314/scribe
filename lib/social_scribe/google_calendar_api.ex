defmodule SocialScribe.GoogleCalendarApi do
  @callback list_events(
              token :: String.t(),
              start_time :: DateTime.t(),
              end_time :: DateTime.t(),
              calendar_id :: String.t()
            ) :: {:ok, list(map())} | {:error, any()}

  def list_events(token, start_time, end_time, calendar_id),
    do: impl().list_events(token, start_time, end_time, calendar_id)

  defp impl,
    do: Application.get_env(:social_scribe, :google_calendar_api, SocialScribe.GoogleCalendar)
end
