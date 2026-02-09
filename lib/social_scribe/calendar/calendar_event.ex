defmodule SocialScribe.Calendar.CalendarEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "calendar_events" do
    field :status, :string
    field :description, :string
    field :location, :string
    field :google_event_id, :string
    field :summary, :string
    field :html_link, :string
    field :hangout_link, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :record_meeting, :boolean, default: false
    field :user_id, :id
    field :user_credential_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(calendar_event, attrs) do
    calendar_event
    |> cast(attrs, [
      :google_event_id,
      :summary,
      :description,
      :location,
      :html_link,
      :hangout_link,
      :status,
      :start_time,
      :end_time,
      :record_meeting,
      :user_id,
      :user_credential_id
    ])
    |> validate_required([
      :google_event_id,
      :summary,
      :html_link,
      :status,
      :start_time,
      :end_time,
      :user_id,
      :user_credential_id
    ])
  end
end
