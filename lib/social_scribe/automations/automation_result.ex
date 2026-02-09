defmodule SocialScribe.Automations.AutomationResult do
  use Ecto.Schema
  import Ecto.Changeset

  schema "automation_results" do
    field :status, :string
    field :generated_content, :string
    field :error_message, :string

    belongs_to :automation, SocialScribe.Automations.Automation
    belongs_to :meeting, SocialScribe.Meetings.Meeting

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(automation_result, attrs) do
    automation_result
    |> cast(attrs, [:generated_content, :status, :error_message, :automation_id, :meeting_id])
    |> validate_required([
      :status,
      :automation_id,
      :meeting_id
    ])
  end
end
