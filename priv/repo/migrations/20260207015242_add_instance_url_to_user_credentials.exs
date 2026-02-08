defmodule SocialScribe.Repo.Migrations.AddInstanceUrlToUserCredentials do
  use Ecto.Migration

  def change do
    alter table(:user_credentials) do
      add :instance_url, :text
    end
  end
end
