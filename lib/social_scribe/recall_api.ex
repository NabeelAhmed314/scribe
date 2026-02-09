defmodule SocialScribe.RecallApi do
  @moduledoc """
  A behaviour for implementing a Recall.ai API client.
  Allows for using a real client in production and a mock client in tests.
  """

  @callback create_bot(meeting_url :: String.t(), join_at :: DateTime.t()) ::
              {:ok, Tesla.Env.t()} | {:error, any()}

  @callback update_bot(
              recall_bot_id :: String.t(),
              meeting_url :: String.t(),
              join_at :: DateTime.t()
            ) ::
              {:ok, Tesla.Env.t()} | {:error, any()}

  @callback delete_bot(recall_bot_id :: String.t()) ::
              {:ok, Tesla.Env.t()} | {:error, any()}

  @callback get_bot(recall_bot_id :: String.t()) ::
              {:ok, Tesla.Env.t()} | {:error, any()}

  @callback get_bot_transcript(recall_bot_id :: String.t()) ::
              {:ok, Tesla.Env.t()} | {:error, any()}

  @callback get_bot_participants(recall_bot_id :: String.t()) ::
              {:ok, Tesla.Env.t()} | {:error, any()}

  def create_bot(meeting_url, join_offset_minutes) do
    impl().create_bot(meeting_url, join_offset_minutes)
  end

  def update_bot(recall_bot_id, meeting_url, join_at) do
    impl().update_bot(recall_bot_id, meeting_url, join_at)
  end

  def delete_bot(recall_bot_id) do
    impl().delete_bot(recall_bot_id)
  end

  def get_bot(recall_bot_id) do
    impl().get_bot(recall_bot_id)
  end

  def get_bot_transcript(recall_bot_id) do
    impl().get_bot_transcript(recall_bot_id)
  end

  def get_bot_participants(recall_bot_id) do
    impl().get_bot_participants(recall_bot_id)
  end

  defp impl do
    Application.get_env(:social_scribe, :recall_api, SocialScribe.Recall)
  end
end
