defmodule SocialScribe.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  chat message entities.
  """

  alias SocialScribe.Chat

  @doc """
  Generate a chat message.
  """
  def chat_message_fixture(attrs \\ %{}) do
    {:ok, chat_message} =
      attrs
      |> Enum.into(%{
        content: "some message content",
        type: "user",
        user_id: attrs[:user_id] || raise("user_id is required"),
        contact_ids: [],
        contact_sources: %{},
        metadata: %{}
      })
      |> Chat.create_message()

    chat_message
  end

  @doc """
  Generate a user-type chat message with tagged contacts.
  """
  def user_message_fixture(user_id, attrs \\ %{}) do
    contacts = attrs[:contacts] || []

    contact_ids = Enum.map(contacts, & &1.id)
    contact_sources =
      contacts
      |> Enum.map(fn c -> {c.id, c.source} end)
      |> Enum.into(%{})

    {:ok, chat_message} =
      attrs
      |> Enum.into(%{
        content: attrs[:content] || "User question about contacts",
        type: "user",
        user_id: user_id,
        contact_ids: contact_ids,
        contact_sources: contact_sources,
        metadata: %{
          tagged_contacts: contacts
        }
      })
      |> Chat.create_message()

    chat_message
  end

  @doc """
  Generate an assistant-type chat message (AI response).
  """
  def assistant_message_fixture(user_id, attrs \\ %{}) do
    {:ok, chat_message} =
      attrs
      |> Enum.into(%{
        content: attrs[:content] || "AI response to user query",
        type: "assistant",
        user_id: user_id,
        contact_ids: [],
        contact_sources: %{},
        metadata: attrs[:metadata] || %{}
      })
      |> Chat.create_message()

    chat_message
  end

  @doc """
  Generate multiple chat messages for testing pagination.
  """
  def chat_message_list_fixture(user_id, count \\ 10) do
    Enum.map(1..count, fn i ->
      type = if rem(i, 2) == 0, do: "assistant", else: "user"

      content =
        case type do
          "user" -> "User question #{i}"
          "assistant" -> "AI response #{i}"
        end

      chat_message_fixture(%{
        user_id: user_id,
        content: content,
        type: type
      })
    end)
  end

  @doc """
  Generate a conversation history with alternating user/assistant messages.
  """
  def conversation_history_fixture(user_id, message_pairs \\ 3) do
    Enum.flat_map(1..message_pairs, fn i ->
      user_msg =
        user_message_fixture(user_id, %{
          content: "Question #{i}"
        })

      assistant_msg =
        assistant_message_fixture(user_id, %{
          content: "Response to question #{i}"
        })

      [user_msg, assistant_msg]
    end)
  end
end
