defmodule SocialScribe.CalendarFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `SocialScribe.Calendar` context.
  """

  import SocialScribe.AccountsFixtures

  @doc """
  Generate a calendar_event.
  """
  def calendar_event_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    user_credential_id =
      attrs[:user_credential_id] ||
        user_credential_fixture(%{user_id: user_id}).id

    {:ok, calendar_event} =
      attrs
      |> Enum.into(%{
        description: "some description",
        end_time: ~U[2025-05-23 19:00:00Z],
        google_event_id: "some google_event_id #{System.unique_integer()}",
        hangout_link: "some hangout_link",
        html_link: "some html_link",
        location: "some location",
        record_meeting: true,
        start_time: ~U[2025-05-23 19:00:00Z],
        status: "some status",
        summary: "some summary",
        user_id: user_id,
        user_credential_id: user_credential_id
      })
      |> SocialScribe.Calendar.create_calendar_event()

    calendar_event
  end
end
