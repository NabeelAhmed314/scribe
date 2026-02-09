defmodule SocialScribe.Repo.Migrations.CreateUserCredentials do
  use Ecto.Migration

  def change do
    create table(:user_credentials) do
      add :provider, :string
      add :uid, :string
      add :token, :text
      add :refresh_token, :text
      add :expires_at, :utc_datetime
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:user_credentials, [:user_id])
    create unique_index(:user_credentials, [:provider, :uid])
  end
end
