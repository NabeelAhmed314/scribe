defmodule SocialScribe.Workers.AIContentGenerationWorker do
  alias SocialScribe.Meetings.Meeting
  use Oban.Worker, queue: :ai_content, max_attempts: 3

  alias SocialScribe.Meetings
  alias SocialScribe.AIContentGeneratorApi
  alias SocialScribe.Automations

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"meeting_id" => meeting_id}}) do
    Logger.info("Starting AI content generation for meeting_id: #{meeting_id}")

    case Meetings.get_meeting_with_details(meeting_id) do
      nil ->
        Logger.error("AIContentGenerationWorker: Meeting not found for id #{meeting_id}")
        {:error, :meeting_not_found}

      meeting ->
        case process_meeting(meeting) do
          :ok ->
            if meeting.calendar_event && meeting.calendar_event.user_id do
              process_user_automations(meeting, meeting.calendar_event.user_id)
              :ok
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp process_meeting(%Meeting{} = meeting) do
    case AIContentGeneratorApi.generate_follow_up_email(meeting) do
      {:ok, email_draft} ->
        Logger.info("Generated follow-up email for meeting #{meeting.id}")

        case Meetings.update_meeting(meeting, %{follow_up_email: email_draft}) do
          {:ok, _updated_meeting} ->
            Logger.info("Successfully saved AI content for meeting #{meeting.id}")
            :ok

          {:error, changeset} ->
            Logger.error(
              "Failed to save AI content for meeting #{meeting.id}: #{inspect(changeset.errors)}"
            )

            {:error, :db_update_failed}
        end

      {:error, reason} ->
        Logger.error(
          "Failed to generate follow-up email for meeting #{meeting.id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp process_user_automations(meeting, user_id) do
    user_automations = Automations.list_active_user_automations(user_id)

    if Enum.empty?(user_automations) do
      Logger.info("No active automations found for user #{user_id} for meeting #{meeting.id}")
      :ok
    else
      Logger.info(
        "Processing #{Enum.count(user_automations)} automations for meeting #{meeting.id}"
      )

      for automation <- user_automations do
        case AIContentGeneratorApi.generate_automation(automation, meeting) do
          {:ok, generated_text} ->
            Automations.create_automation_result(%{
              automation_id: automation.id,
              meeting_id: meeting.id,
              generated_content: generated_text,
              status: "draft"
            })

            Logger.info(
              "Successfully generated content for automation '#{automation.name}', meeting #{meeting.id}"
            )

          {:error, reason} ->
            Automations.create_automation_result(%{
              automation_id: automation.id,
              meeting_id: meeting.id,
              status: "generation_failed",
              error_message: "Gemini API error: #{inspect(reason)}"
            })

            Logger.error(
              "Failed to generate content for automation '#{automation.name}', meeting #{meeting.id}: #{inspect(reason)}"
            )
        end
      end
    end
  end
end
