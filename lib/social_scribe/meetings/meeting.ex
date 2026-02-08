defmodule SocialScribe.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  alias SocialScribe.Meetings.{MeetingTranscript, MeetingParticipant}
  alias SocialScribe.Calendar.CalendarEvent
  alias SocialScribe.Bots.RecallBot

  schema "meetings" do
    field :title, :string
    field :recorded_at, :utc_datetime
    field :duration_seconds, :integer
    field :follow_up_email, :string

    belongs_to :calendar_event, CalendarEvent
    belongs_to :recall_bot, RecallBot

    has_one :meeting_transcript, MeetingTranscript
    has_many :meeting_participants, MeetingParticipant

    timestamps()
  end

  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [
      :title,
      :recorded_at,
      :duration_seconds,
      :calendar_event_id,
      :recall_bot_id,
      :follow_up_email
    ])
    |> validate_required([:title, :recorded_at, :calendar_event_id, :recall_bot_id])
  end
end
