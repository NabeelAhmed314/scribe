defmodule SocialScribe.GoogleCalendar do
  @moduledoc """
  Simplified Google Calendar API client.
  """

  @base_url "https://www.googleapis.com/calendar/v3"

  @behaviour SocialScribe.GoogleCalendarApi

  # TODO: Mock for testing
  def list_events(token, start_time, end_time, calendar_id) do
    Tesla.get(client(token), "/calendars/#{calendar_id}/events",
      query: [
        timeMin: Timex.format!(start_time, "{RFC3339}"),
        timeMax: Timex.format!(end_time, "{RFC3339}"),
        singleEvents: true,
        orderBy: "startTime"
      ]
    )
    |> case do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        {:error, {status, error_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp client(token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @base_url},
      {Tesla.Middleware.Headers, [{"Authorization", "Bearer #{token}"}]},
      Tesla.Middleware.JSON
    ])
  end
end
