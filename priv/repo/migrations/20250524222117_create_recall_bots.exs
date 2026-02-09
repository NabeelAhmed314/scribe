defmodule SocialScribe.Repo.Migrations.CreateRecallBots do
  use Ecto.Migration

  def change do
    create table(:recall_bots) do
      add :recall_bot_id, :string
      add :status, :string
      add :meeting_url, :string
      add :user_id, references(:users, on_delete: :nothing)
      add :calendar_event_id, references(:calendar_events, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:recall_bots, [:recall_bot_id])
    create index(:recall_bots, [:user_id])
    create index(:recall_bots, [:calendar_event_id])
  end
end
