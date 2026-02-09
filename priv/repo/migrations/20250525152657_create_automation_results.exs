defmodule SocialScribe.Repo.Migrations.CreateAutomationResults do
  use Ecto.Migration

  def change do
    create table(:automation_results) do
      add :generated_content, :text
      add :status, :string
      add :error_message, :text
      add :automation_id, references(:automations, on_delete: :delete_all), null: false
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:automation_results, [:automation_id])
    create index(:automation_results, [:meeting_id])
    create index(:automation_results, [:status])
    create unique_index(:automation_results, [:automation_id, :meeting_id])
  end
end
