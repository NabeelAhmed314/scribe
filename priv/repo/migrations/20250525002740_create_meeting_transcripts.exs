defmodule SocialScribe.Repo.Migrations.CreateMeetingTranscripts do
  use Ecto.Migration

  def change do
    create table(:meeting_transcripts) do
      add :content, :map
      add :language, :string
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false, unique: true

      timestamps(type: :utc_datetime)
    end

    create index(:meeting_transcripts, [:meeting_id])
  end
end
