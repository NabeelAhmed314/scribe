defmodule SocialScribe.Bots.UserBotPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_bot_preferences" do
    field :join_minute_offset, :integer, default: 2
    belongs_to :user, SocialScribe.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_bot_preference, attrs) do
    user_bot_preference
    |> cast(attrs, [:user_id, :join_minute_offset])
    |> validate_required([:user_id, :join_minute_offset])
    |> unique_constraint(:user_id)
    |> validate_inclusion(:join_minute_offset, 0..10, message: "must be between 0 and 10")
  end
end
