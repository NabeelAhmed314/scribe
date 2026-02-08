defmodule SocialScribe.Chat.ChatMessage do
  @moduledoc """
  Schema for chat messages in the CRM Chat Assistant.
  Stores both user messages and AI assistant responses.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field :content, :string
    field :type, :string
    field :contact_ids, {:array, :string}
    field :contact_sources, :map
    field :metadata, :map

    belongs_to :user, SocialScribe.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:user_id, :content, :type, :contact_ids, :contact_sources, :metadata])
    |> validate_required([:user_id, :content, :type])
    |> validate_inclusion(:type, ["user", "assistant"])
    |> validate_length(:content, min: 1)
    |> foreign_key_constraint(:user_id)
  end
end
