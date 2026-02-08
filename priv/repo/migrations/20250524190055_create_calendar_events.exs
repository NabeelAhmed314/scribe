defmodule SocialScribe.Repo.Migrations.CreateCalendarEvents do
  use Ecto.Migration

  def change do
    create table(:calendar_events) do
      add :google_event_id, :string
      add :summary, :string
      add :description, :text
      add :location, :string
      add :html_link, :string
      add :hangout_link, :string
      add :status, :string
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime
      add :record_meeting, :boolean, default: false, null: false
      add :user_id, references(:users, on_delete: :delete_all)
      add :user_credential_id, references(:user_credentials, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:calendar_events, [:user_id])
    create index(:calendar_events, [:user_credential_id])
    create unique_index(:calendar_events, [:user_id, :google_event_id])
  end
end
