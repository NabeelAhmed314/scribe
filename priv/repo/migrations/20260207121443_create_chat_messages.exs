defmodule SocialScribe.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :type, :string, null: false
      add :contact_ids, {:array, :string}
      add :contact_sources, :map
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:user_id])
    create index(:chat_messages, [:inserted_at])
  end
end
