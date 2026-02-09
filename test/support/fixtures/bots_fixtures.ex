defmodule SocialScribe.BotsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `SocialScribe.Bots` context.
  """
  import SocialScribe.AccountsFixtures
  import SocialScribe.CalendarFixtures

  @doc """
  Generate a unique recall_bot recall_bot_id.
  """
  def unique_recall_bot_recall_bot_id,
    do: "some recall_bot_id#{System.unique_integer([:positive])}"

  @doc """
  Generate a recall_bot.
  """
  def recall_bot_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    calendar_event_id = attrs[:calendar_event_id] || calendar_event_fixture().id

    {:ok, recall_bot} =
      attrs
      |> Enum.into(%{
        meeting_url: "some meeting_url",
        recall_bot_id: unique_recall_bot_recall_bot_id(),
        status: "some status",
        user_id: user_id,
        calendar_event_id: calendar_event_id
      })
      |> SocialScribe.Bots.create_recall_bot()

    recall_bot
  end

  @doc """
  Generate a user_bot_preference.
  """
  def user_bot_preference_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    {:ok, user_bot_preference} =
      attrs
      |> Enum.into(%{
        join_minute_offset: 2,
        user_id: user_id
      })
      |> SocialScribe.Bots.create_user_bot_preference()

    user_bot_preference
  end
end
