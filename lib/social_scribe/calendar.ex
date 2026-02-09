defmodule SocialScribe.Calendar do
  @moduledoc """
  The Calendar context.
  """

  import Ecto.Query, warn: false

  alias SocialScribe.Repo

  alias SocialScribe.Calendar.CalendarEvent

  @doc """
  Lists all upcoming events for a given user from the local database.
  """
  def list_upcoming_events(user) do
    from(e in CalendarEvent,
      where: e.user_id == ^user.id and e.start_time > ^DateTime.utc_now(),
      order_by: [asc: e.start_time]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of calendar_events.

  ## Examples

      iex> list_calendar_events()
      [%CalendarEvent{}, ...]

  """
  def list_calendar_events do
    Repo.all(CalendarEvent)
  end

  @doc """
  Gets a single calendar_event.

  Raises `Ecto.NoResultsError` if the Calendar event does not exist.

  ## Examples

      iex> get_calendar_event!(123)
      %CalendarEvent{}

      iex> get_calendar_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_calendar_event!(id), do: Repo.get!(CalendarEvent, id)

  @doc """
  Creates a calendar_event.

  ## Examples

      iex> create_calendar_event(%{field: value})
      {:ok, %CalendarEvent{}}

      iex> create_calendar_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_calendar_event(attrs \\ %{}) do
    %CalendarEvent{}
    |> CalendarEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a calendar_event.

  ## Examples

      iex> update_calendar_event(calendar_event, %{field: new_value})
      {:ok, %CalendarEvent{}}

      iex> update_calendar_event(calendar_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_calendar_event(%CalendarEvent{} = calendar_event, attrs) do
    calendar_event
    |> CalendarEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a calendar_event.

  ## Examples

      iex> delete_calendar_event(calendar_event)
      {:ok, %CalendarEvent{}}

      iex> delete_calendar_event(calendar_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_calendar_event(%CalendarEvent{} = calendar_event) do
    Repo.delete(calendar_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking calendar_event changes.

  ## Examples

      iex> change_calendar_event(calendar_event)
      %Ecto.Changeset{data: %CalendarEvent{}}

  """
  def change_calendar_event(%CalendarEvent{} = calendar_event, attrs \\ %{}) do
    CalendarEvent.changeset(calendar_event, attrs)
  end

  @doc """
  Creates or updates a calendar event.

  ## Examples

      iex> create_or_update_calendar_event(%{field: value})
      {:ok, %CalendarEvent{}}

  """
  def create_or_update_calendar_event(attrs \\ %{}) do
    on_conflict =
      attrs
      |> Map.delete(:record_meeting)
      |> Map.to_list()

    %CalendarEvent{}
    |> CalendarEvent.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: on_conflict],
      conflict_target: [:user_id, :google_event_id]
    )
  end
end
