defmodule SocialScribe.Repo.Migrations.CreateMeetings do
  use Ecto.Migration

  def change do
    create table(:meetings) do
      add :title, :string
      add :recorded_at, :utc_datetime
      add :duration_seconds, :integer
      add :calendar_event_id, references(:calendar_events, on_delete: :delete_all), null: false

      add :recall_bot_id, references(:recall_bots, on_delete: :delete_all),
        null: false,
        unique: true

      timestamps(type: :utc_datetime)
    end

    create index(:meetings, [:calendar_event_id])
    create index(:meetings, [:recall_bot_id])
  end
end
