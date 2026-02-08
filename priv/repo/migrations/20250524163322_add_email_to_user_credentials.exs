defmodule SocialScribe.Repo.Migrations.AddEmailToUserCredentials do
  use Ecto.Migration

  def change do
    alter table(:user_credentials) do
      add :email, :string
    end
  end
end
