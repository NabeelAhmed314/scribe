defmodule SocialScribe.Repo.Migrations.AddFollowUpEmailMeeting do
  use Ecto.Migration

  def change do
    alter table(:meetings) do
      add :follow_up_email, :string
    end
  end
end
