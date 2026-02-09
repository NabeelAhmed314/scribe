defmodule SocialScribe.Workers.AIContentGenerationWorkerTest do
  use SocialScribe.DataCase, async: true

  import Mox
  import SocialScribe.MeetingsFixtures
  import SocialScribe.MeetingTranscriptExample
  import SocialScribe.AutomationsFixtures
  import SocialScribe.BotsFixtures
  import SocialScribe.CalendarFixtures
  import SocialScribe.AccountsFixtures

  alias SocialScribe.Workers.AIContentGenerationWorker
  alias SocialScribe.AIContentGeneratorMock, as: AIGeneratorMock
  alias SocialScribe.Meetings
  alias SocialScribe.Automations

  # Ensure this matches your worker's expectation
  @mock_transcript_data %{"data" => meeting_transcript_example()}
  @generated_email_draft "This is a generated follow-up email draft."

  describe "perform/1" do
    setup do
      stub_with(AIGeneratorMock, SocialScribe.AIContentGenerator)
      :ok
    end

    test "successfully generates and saves a follow-up email" do
      meeting = meeting_fixture()
      meeting_transcript_fixture(%{meeting_id: meeting.id, content: @mock_transcript_data})

      job_args = %{"meeting_id" => meeting.id}

      expect(AIGeneratorMock, :generate_follow_up_email, fn meeting ->
        assert meeting ==
                 Repo.preload(meeting, [
                   :calendar_event,
                   :meeting_participants,
                   :meeting_transcript,
                   :recall_bot
                 ])

        {:ok, @generated_email_draft}
      end)

      assert AIContentGenerationWorker.perform(%Oban.Job{args: job_args}) == :ok

      updated_meeting = Meetings.get_meeting_with_details(meeting.id)
      assert updated_meeting.follow_up_email == @generated_email_draft
    end

    test "successfully generates and saves automation results" do
      user = user_fixture()
      automation_fixture(%{user_id: user.id, is_active: true})
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      recall_bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user.id})

      meeting =
        meeting_fixture(%{calendar_event_id: calendar_event.id, recall_bot_id: recall_bot.id})

      meeting_participant_fixture(%{meeting_id: meeting.id, is_host: true})
      meeting_transcript_fixture(%{meeting_id: meeting.id, content: @mock_transcript_data})

      job_args = %{"meeting_id" => meeting.id}

      expect(AIGeneratorMock, :generate_follow_up_email, fn _ ->
        {:ok, @generated_email_draft}
      end)

      expect(AIGeneratorMock, :generate_automation, fn automation, meeting ->
        assert automation == automation

        assert meeting ==
                 Repo.preload(meeting, [
                   :calendar_event,
                   :meeting_participants,
                   :meeting_transcript,
                   :recall_bot
                 ])

        {:ok, @generated_email_draft}
      end)

      assert AIContentGenerationWorker.perform(%Oban.Job{args: job_args}) == :ok

      automation_results =
        Automations.list_automation_results_for_meeting(meeting.id)

      assert length(automation_results) == 1
      assert List.first(automation_results).generated_content == @generated_email_draft
    end

    test "returns {:error, :meeting_not_found} if meeting_id is invalid" do
      job_args = %{"meeting_id" => System.unique_integer([:positive])}

      assert AIContentGenerationWorker.perform(%Oban.Job{args: job_args}) ==
               {:error, :meeting_not_found}
    end

    test "returns {:error, :no_transcript} if meeting has no transcript content" do
      meeting_with_empty_transcript_content = meeting_fixture()

      job_args_no_data = %{"meeting_id" => meeting_with_empty_transcript_content.id}

      assert AIContentGenerationWorker.perform(%Oban.Job{args: job_args_no_data}) ==
               {:error, :no_participants}

      meeting_participant_fixture(%{
        meeting_id: meeting_with_empty_transcript_content.id,
        is_host: true
      })

      assert AIContentGenerationWorker.perform(%Oban.Job{args: job_args_no_data}) ==
               {:error, :no_transcript}
    end

    test "handles failure from AIContentGenerator.generate_follow_up_email" do
      meeting = meeting_fixture()
      meeting_transcript_fixture(%{meeting_id: meeting.id, content: @mock_transcript_data})

      job_args = %{"meeting_id" => meeting.id}

      expect(AIGeneratorMock, :generate_follow_up_email, fn _ ->
        {:error, :gemini_api_timeout}
      end)

      assert AIContentGenerationWorker.perform(%Oban.Job{args: job_args}) ==
               {:error, :gemini_api_timeout}

      refreshed_meeting = Meetings.get_meeting_with_details(meeting.id)
      assert is_nil(refreshed_meeting.follow_up_email)
    end
  end
end
