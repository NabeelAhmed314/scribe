defmodule SocialScribe.Bots do
  @moduledoc """
  The Bots context.
  """

  import Ecto.Query, warn: false
  alias SocialScribe.Repo

  alias SocialScribe.Bots.RecallBot
  alias SocialScribe.Bots.UserBotPreference
  alias SocialScribe.RecallApi

  @doc """
  Returns the list of recall_bots.

  ## Examples

      iex> list_recall_bots()
      [%RecallBot{}, ...]

  """
  def list_recall_bots do
    Repo.all(RecallBot)
  end

  @doc """
  Lists all bots whose status is not yet "done" or "error".
  These are the bots that the poller should check.
  """
  def list_pending_bots do
    from(b in RecallBot, where: b.status not in ["done", "error", "polling_error"])
    |> Repo.all()
  end

  @doc """
  Gets a single recall_bot.

  Raises `Ecto.NoResultsError` if the Recall bot does not exist.

  ## Examples

      iex> get_recall_bot!(123)
      %RecallBot{}

      iex> get_recall_bot!(456)
      ** (Ecto.NoResultsError)

  """
  def get_recall_bot!(id), do: Repo.get!(RecallBot, id)

  @doc """
  Creates a recall_bot.

  ## Examples

      iex> create_recall_bot(%{field: value})
      {:ok, %RecallBot{}}

      iex> create_recall_bot(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_recall_bot(attrs \\ %{}) do
    %RecallBot{}
    |> RecallBot.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a recall_bot.

  ## Examples

      iex> update_recall_bot(recall_bot, %{field: new_value})
      {:ok, %RecallBot{}}

      iex> update_recall_bot(recall_bot, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_recall_bot(%RecallBot{} = recall_bot, attrs) do
    recall_bot
    |> RecallBot.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a recall_bot.

  ## Examples

      iex> delete_recall_bot(recall_bot)
      {:ok, %RecallBot{}}

      iex> delete_recall_bot(recall_bot)
      {:error, %Ecto.Changeset{}}

  """
  def delete_recall_bot(%RecallBot{} = recall_bot) do
    Repo.delete(recall_bot)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking recall_bot changes.

  ## Examples

      iex> change_recall_bot(recall_bot)
      %Ecto.Changeset{data: %RecallBot{}}

  """
  def change_recall_bot(%RecallBot{} = recall_bot, attrs \\ %{}) do
    RecallBot.changeset(recall_bot, attrs)
  end

  # --- Orchestration Functions ---

  @doc """
  Orchestrates creating a bot via the API and saving it to the database.
  """
  def create_and_dispatch_bot(user, calendar_event) do
    user_bot_preference = get_user_bot_preference(user.id) || %UserBotPreference{}
    join_minute_offset = user_bot_preference.join_minute_offset

    with {:ok, %{status: status, body: api_response}} when status in 200..299 <-
           RecallApi.create_bot(
             calendar_event.hangout_link,
             DateTime.add(
               calendar_event.start_time,
               -join_minute_offset,
               :minute
             )
           ),
         %{id: bot_id} <- api_response do
      status = get_in(api_response, [:status_changes, Access.at(0), :code]) || "ready"

      create_recall_bot(%{
        user_id: user.id,
        calendar_event_id: calendar_event.id,
        recall_bot_id: bot_id,
        meeting_url: calendar_event.hangout_link,
        status: status
      })
    else
      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, {status, body}}}

      {:error, reason} ->
        {:error, {:api_error, reason}}

      _ ->
        {:error, {:api_error, :invalid_response}}
    end
  end

  @doc """
  Orchestrates deleting a bot via the API and removing it from the database.
  """
  def cancel_and_delete_bot(calendar_event) do
    case Repo.get_by(RecallBot, calendar_event_id: calendar_event.id) do
      nil ->
        {:ok, :no_bot_to_cancel}

      %RecallBot{} = bot ->
        case RecallApi.delete_bot(bot.recall_bot_id) do
          {:ok, %{status: 404}} -> delete_recall_bot(bot)
          {:ok, _} -> delete_recall_bot(bot)
          {:error, reason} -> {:error, {:api_error, reason}}
        end
    end
  end

  @doc """
  Orchestrates updating a bot's schedule via the API and saving it to the database.
  """
  def update_bot_schedule(bot, calendar_event) do
    user_bot_preference = get_user_bot_preference(bot.user_id) || %UserBotPreference{}
    join_minute_offset = user_bot_preference.join_minute_offset

    with {:ok, %{body: api_response}} <-
           RecallApi.update_bot(
             bot.recall_bot_id,
             calendar_event.hangout_link,
             DateTime.add(calendar_event.start_time, -join_minute_offset, :minute)
           ) do
      update_recall_bot(bot, %{
        status: api_response.status_changes |> List.first() |> Map.get(:code)
      })
    end
  end

  @doc """
  Returns the list of user_bot_preferences.

  ## Examples

      iex> list_user_bot_preferences()
      [%UserBotPreference{}, ...]

  """
  def list_user_bot_preferences do
    Repo.all(UserBotPreference)
  end

  @doc """
  Gets a single user_bot_preference.

  Raises `Ecto.NoResultsError` if the User bot preference does not exist.

  ## Examples

      iex> get_user_bot_preference!(123)
      %UserBotPreference{}

      iex> get_user_bot_preference!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_bot_preference!(id), do: Repo.get!(UserBotPreference, id)

  def get_user_bot_preference(user_id) do
    Repo.get_by(UserBotPreference, user_id: user_id)
  end

  @doc """
  Creates a user_bot_preference.

  ## Examples

      iex> create_user_bot_preference(%{field: value})
      {:ok, %UserBotPreference{}}

      iex> create_user_bot_preference(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_bot_preference(attrs \\ %{}) do
    %UserBotPreference{}
    |> UserBotPreference.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_bot_preference.

  ## Examples

      iex> update_user_bot_preference(user_bot_preference, %{field: new_value})
      {:ok, %UserBotPreference{}}

      iex> update_user_bot_preference(user_bot_preference, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_bot_preference(%UserBotPreference{} = user_bot_preference, attrs) do
    user_bot_preference
    |> UserBotPreference.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user_bot_preference.

  ## Examples

      iex> delete_user_bot_preference(user_bot_preference)
      {:ok, %UserBotPreference{}}

      iex> delete_user_bot_preference(user_bot_preference)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_bot_preference(%UserBotPreference{} = user_bot_preference) do
    Repo.delete(user_bot_preference)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_bot_preference changes.

  ## Examples

      iex> change_user_bot_preference(user_bot_preference)
      %Ecto.Changeset{data: %UserBotPreference{}}

  """
  def change_user_bot_preference(%UserBotPreference{} = user_bot_preference, attrs \\ %{}) do
    UserBotPreference.changeset(user_bot_preference, attrs)
  end
end
