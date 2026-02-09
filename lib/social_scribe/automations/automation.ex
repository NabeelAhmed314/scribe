defmodule SocialScribe.Automations.Automation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "automations" do
    field :name, :string
    field :description, :string
    field :platform, Ecto.Enum, values: [:linkedin, :facebook]
    field :example, :string
    field :is_active, :boolean, default: true

    belongs_to :user, SocialScribe.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(automation, attrs) do
    automation
    |> cast(attrs, [:name, :platform, :description, :example, :is_active, :user_id])
    |> validate_required([:name, :platform, :description, :example, :is_active, :user_id])
  end
end
