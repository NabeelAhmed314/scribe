defmodule SocialScribe.Repo.Migrations.CreateFacebookPageCredentials do
  use Ecto.Migration

  def change do
    create table(:facebook_page_credentials) do
      add :facebook_page_id, :string, null: false
      add :page_name, :string
      add :page_access_token, :text, null: false
      add :category, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :user_credential_id, references(:user_credentials, on_delete: :delete_all), null: false
      add :selected, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:facebook_page_credentials, [:facebook_page_id])
    create index(:facebook_page_credentials, [:user_id])
    create index(:facebook_page_credentials, [:user_credential_id])
    create unique_index(:facebook_page_credentials, [:user_id, :selected])
  end
end
