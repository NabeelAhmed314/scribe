defmodule SocialScribe.MeetingsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `SocialScribe.Meetings` context.
  """

  alias SocialScribe.Calendar
  import SocialScribe.CalendarFixtures
  import SocialScribe.BotsFixtures

  @doc """
  Generate a meeting.
  """
  def meeting_fixture(attrs \\ %{}) do
    calendar_event =
      if attrs[:calendar_event_id] do
        Calendar.get_calendar_event!(attrs[:calendar_event_id])
      else
        calendar_event_fixture()
      end

    recall_bot_id =
      attrs[:recall_bot_id] ||
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        }).id

    {:ok, meeting} =
      attrs
      |> Enum.into(%{
        duration_seconds: 42,
        recorded_at: ~U[2025-05-24 00:27:00Z],
        title: "some title",
        calendar_event_id: calendar_event.id,
        recall_bot_id: recall_bot_id
      })
      |> SocialScribe.Meetings.create_meeting()

    meeting
  end

  @doc """
  Generate a meeting_transcript.
  """
  def meeting_transcript_fixture(attrs \\ %{}) do
    meeting_id = attrs[:meeting_id] || meeting_fixture().id

    {:ok, meeting_transcript} =
      attrs
      |> Enum.into(%{
        content: %{},
        language: "some language",
        meeting_id: meeting_id
      })
      |> SocialScribe.Meetings.create_meeting_transcript()

    meeting_transcript
  end

  @doc """
  Generate a meeting_participant.
  """
  def meeting_participant_fixture(attrs \\ %{}) do
    meeting_id = attrs[:meeting_id] || meeting_fixture().id

    {:ok, meeting_participant} =
      attrs
      |> Enum.into(%{
        is_host: true,
        name: "some name",
        recall_participant_id:
          "some recall_participant_id <> #{System.unique_integer([:positive])}",
        meeting_id: meeting_id
      })
      |> SocialScribe.Meetings.create_meeting_participant()

    meeting_participant
  end
end
