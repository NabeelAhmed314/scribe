defmodule SocialScribe.Repo.Migrations.CreateMeetingParticipants do
  use Ecto.Migration

  def change do
    create table(:meeting_participants) do
      add :recall_participant_id, :string
      add :name, :string
      add :is_host, :boolean, default: false, null: false
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:meeting_participants, [:meeting_id])
    create unique_index(:meeting_participants, [:meeting_id, :recall_participant_id])
  end
end
