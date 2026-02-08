defmodule SocialScribe.Workers.BotStatusPoller do
  use Oban.Worker, queue: :polling, max_attempts: 3

  alias SocialScribe.Bots
  alias SocialScribe.RecallApi
  alias SocialScribe.Meetings

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    bots_to_poll = Bots.list_pending_bots()

    if Enum.any?(bots_to_poll) do
      Logger.info("Polling #{Enum.count(bots_to_poll)} pending Recall.ai bots...")
    end

    for bot_record <- bots_to_poll do
      poll_and_process_bot(bot_record)
    end

    :ok
  end

  defp poll_and_process_bot(bot_record) do
    case RecallApi.get_bot(bot_record.recall_bot_id) do
      {:ok, %Tesla.Env{body: bot_api_info}} ->
        new_status =
          bot_api_info
          |> Map.get(:status_changes)
          |> List.last()
          |> Map.get(:code)

        {:ok, updated_bot_record} = Bots.update_recall_bot(bot_record, %{status: new_status})

        if new_status == "done" &&
             is_nil(Meetings.get_meeting_by_recall_bot_id(updated_bot_record.id)) do
          process_completed_bot(updated_bot_record, bot_api_info)
        else
          if new_status != bot_record.status do
            Logger.info("Bot #{bot_record.recall_bot_id} status updated to: #{new_status}")
          end
        end

      {:error, reason} ->
        Logger.error(
          "Failed to poll bot status for #{bot_record.recall_bot_id}: #{inspect(reason)}"
        )

        Bots.update_recall_bot(bot_record, %{status: "polling_error"})
    end
  end

  defp process_completed_bot(bot_record, bot_api_info) do
    Logger.info("Bot #{bot_record.recall_bot_id} is done. Fetching transcript and participants...")

    with {:ok, %Tesla.Env{body: transcript_data}} <-
           RecallApi.get_bot_transcript(bot_record.recall_bot_id),
         {:ok, participants_data} <- fetch_participants(bot_record.recall_bot_id) do
      Logger.info("Successfully fetched transcript and participants for bot #{bot_record.recall_bot_id}")

      case Meetings.create_meeting_from_recall_data(bot_record, bot_api_info, transcript_data, participants_data) do
        {:ok, meeting} ->
          Logger.info(
            "Successfully created meeting record #{meeting.id} from bot #{bot_record.recall_bot_id}"
          )

          SocialScribe.Workers.AIContentGenerationWorker.new(%{meeting_id: meeting.id})
          |> Oban.insert()

          Logger.info("Enqueued AI content generation for meeting #{meeting.id}")

        {:error, reason} ->
          Logger.error(
            "Failed to create meeting record from bot #{bot_record.recall_bot_id}: #{inspect(reason)}"
          )
      end
    else
      {:error, reason} ->
        Logger.error(
          "Failed to fetch data for bot #{bot_record.recall_bot_id} after completion: #{inspect(reason)}"
        )
    end
  end

  defp fetch_participants(recall_bot_id) do
    case RecallApi.get_bot_participants(recall_bot_id) do
      {:ok, %Tesla.Env{body: participants_data}} ->
        {:ok, participants_data}

      {:error, reason} ->
        Logger.warning("Could not fetch participants for bot #{recall_bot_id}: #{inspect(reason)}, falling back to empty list")
        {:ok, []}
    end
  end
end
