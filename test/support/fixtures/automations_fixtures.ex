defmodule SocialScribe.AutomationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `SocialScribe.Automations` context.
  """

  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures

  @doc """
  Generate a automation.
  """
  def automation_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    {:ok, automation} =
      attrs
      |> Enum.into(%{
        description: "some description",
        is_active: true,
        name: "some name #{System.unique_integer([:positive])}",
        platform: :linkedin,
        example: "some example",
        user_id: user_id
      })
      |> SocialScribe.Automations.create_automation()

    automation
  end

  @doc """
  Generate a automation_result.
  """
  def automation_result_fixture(attrs \\ %{}) do
    automation_id = attrs[:automation_id] || automation_fixture().id
    meeting_id = attrs[:meeting_id] || meeting_fixture().id

    {:ok, automation_result} =
      attrs
      |> Enum.into(%{
        automation_id: automation_id,
        meeting_id: meeting_id,
        status: "some status",
        generated_content: "some generated_content",
        error_message: "some error_message"
      })
      |> SocialScribe.Automations.create_automation_result()

    automation_result
  end
end
