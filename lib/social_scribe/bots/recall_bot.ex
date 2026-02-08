defmodule SocialScribe.Bots.RecallBot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recall_bots" do
    field :status, :string
    field :recall_bot_id, :string
    field :meeting_url, :string

    belongs_to :user, SocialScribe.Accounts.User
    belongs_to :calendar_event, SocialScribe.Calendar.CalendarEvent

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(recall_bot, attrs) do
    recall_bot
    |> cast(attrs, [:recall_bot_id, :status, :meeting_url, :user_id, :calendar_event_id])
    |> validate_required([:recall_bot_id, :status, :meeting_url, :user_id, :calendar_event_id])
    |> unique_constraint(:recall_bot_id)
  end
end
