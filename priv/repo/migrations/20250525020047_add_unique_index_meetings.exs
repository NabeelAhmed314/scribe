defmodule SocialScribe.Repo.Migrations.AddUniqueIndexMeetings do
  use Ecto.Migration

  def change do
    create unique_index(:meetings, [:recall_bot_id], name: :meetings_recall_bot_id_unique_index)
  end
end
