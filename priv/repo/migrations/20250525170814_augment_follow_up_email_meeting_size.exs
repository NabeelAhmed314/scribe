defmodule SocialScribe.Repo.Migrations.AugmentFollowUpEmailMeetingSize do
  use Ecto.Migration

  def change do
    alter table(:meetings) do
      modify :follow_up_email, :text
    end
  end
end
