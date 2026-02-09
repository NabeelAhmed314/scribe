defmodule SocialScribe.Chat do
  @moduledoc """
  The Chat context for managing chat messages in the CRM Chat Assistant.
  """

  import Ecto.Query, warn: false

  alias SocialScribe.Repo
  alias SocialScribe.Chat.ChatMessage

  @doc """
  Returns the list of chat messages for a user, ordered by inserted_at DESC.

  ## Examples

      iex> list_user_messages(user_id)
      [%ChatMessage{}, ...]

  """
  def list_user_messages(user_id) do
    ChatMessage
    |> where(user_id: ^user_id)
    |> order_by(desc: :id)
    |> Repo.all()
  end

  @doc """
  Returns recent chat messages for a user with a limit.

  ## Examples

      iex> list_recent_user_messages(user_id, 50)
      [%ChatMessage{}, ...]

  """
  def list_recent_user_messages(user_id, limit \\ 50) do
    ChatMessage
    |> where(user_id: ^user_id)
    |> order_by(desc: :id)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Creates a chat message.

  ## Examples

      iex> create_message(%{field: value})
      {:ok, %ChatMessage{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(attrs \\ %{}) do
    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single chat message.

  Raises `Ecto.NoResultsError` if the ChatMessage does not exist.

  ## Examples

      iex> get_message!(123)
      %ChatMessage{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(id), do: Repo.get!(ChatMessage, id)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking chat message changes.

  ## Examples

      iex> change_message(chat_message)
      %Ecto.Changeset{data: %ChatMessage{}}

  """
  def change_message(%ChatMessage{} = chat_message, attrs \\ %{}) do
    ChatMessage.changeset(chat_message, attrs)
  end
end
