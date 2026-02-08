defmodule SocialScribe.Repo.Migrations.CreateUserBotPreferences do
  use Ecto.Migration

  def change do
    create table(:user_bot_preferences) do
      add :join_minute_offset, :integer, null: false, default: 2
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_bot_preferences, [:user_id])
  end
end
