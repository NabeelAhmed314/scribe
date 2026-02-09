defmodule SocialScribe.CalendarTest do
  use SocialScribe.DataCase

  alias SocialScribe.Calendar

  describe "calendar_events" do
    alias SocialScribe.Calendar.CalendarEvent

    import SocialScribe.CalendarFixtures
    import SocialScribe.AccountsFixtures

    @invalid_attrs %{
      status: nil,
      description: nil,
      location: nil,
      google_event_id: nil,
      summary: nil,
      html_link: nil,
      hangout_link: nil,
      start_time: nil,
      end_time: nil,
      record_meeting: nil
    }

    test "list_upcoming_events/1 returns all upcoming events for a given user" do
      user = user_fixture()
      user_credential = user_credential_fixture(%{user_id: user.id})

      upcoming_event =
        calendar_event_fixture(%{
          user_id: user.id,
          user_credential_id: user_credential.id,
          start_time: DateTime.add(DateTime.utc_now(), 1, :hour)
        })

      assert Calendar.list_upcoming_events(user) == [upcoming_event]
    end

    test "list_upcoming_events/1 returns an empty list if there are no upcoming events" do
      user = user_fixture()
      user_credential = user_credential_fixture(%{user_id: user.id})

      _past_event =
        calendar_event_fixture(%{
          user_id: user.id,
          user_credential_id: user_credential.id,
          start_time: DateTime.add(DateTime.utc_now(), -1, :hour)
        })

      assert Calendar.list_upcoming_events(user) == []
    end

    test "list_calendar_events/0 returns all calendar_events" do
      calendar_event = calendar_event_fixture()
      assert Calendar.list_calendar_events() == [calendar_event]
    end

    test "get_calendar_event!/1 returns the calendar_event with given id" do
      calendar_event = calendar_event_fixture()
      assert Calendar.get_calendar_event!(calendar_event.id) == calendar_event
    end

    test "create_calendar_event/1 with valid data creates a calendar_event" do
      user = user_fixture()
      user_credential = user_credential_fixture(%{user_id: user.id})

      valid_attrs = %{
        status: "some status",
        description: "some description",
        location: "some location",
        google_event_id: "some google_event_id",
        summary: "some summary",
        html_link: "some html_link",
        hangout_link: "some hangout_link",
        start_time: ~U[2025-05-23 19:00:00Z],
        end_time: ~U[2025-05-23 19:00:00Z],
        record_meeting: true,
        user_id: user.id,
        user_credential_id: user_credential.id
      }

      assert {:ok, %CalendarEvent{} = calendar_event} =
               Calendar.create_calendar_event(valid_attrs)

      assert calendar_event.status == "some status"
      assert calendar_event.description == "some description"
      assert calendar_event.location == "some location"
      assert calendar_event.google_event_id == "some google_event_id"
      assert calendar_event.summary == "some summary"
      assert calendar_event.html_link == "some html_link"
      assert calendar_event.hangout_link == "some hangout_link"
      assert calendar_event.start_time == ~U[2025-05-23 19:00:00Z]
      assert calendar_event.end_time == ~U[2025-05-23 19:00:00Z]
      assert calendar_event.record_meeting == true
    end

    test "create_calendar_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Calendar.create_calendar_event(@invalid_attrs)
    end

    test "update_calendar_event/2 with valid data updates the calendar_event" do
      calendar_event = calendar_event_fixture()

      update_attrs = %{
        status: "some updated status",
        description: "some updated description",
        location: "some updated location",
        google_event_id: "some updated google_event_id",
        summary: "some updated summary",
        html_link: "some updated html_link",
        hangout_link: "some updated hangout_link",
        start_time: ~U[2025-05-24 19:00:00Z],
        end_time: ~U[2025-05-24 19:00:00Z],
        record_meeting: false
      }

      assert {:ok, %CalendarEvent{} = calendar_event} =
               Calendar.update_calendar_event(calendar_event, update_attrs)

      assert calendar_event.status == "some updated status"
      assert calendar_event.description == "some updated description"
      assert calendar_event.location == "some updated location"
      assert calendar_event.google_event_id == "some updated google_event_id"
      assert calendar_event.summary == "some updated summary"
      assert calendar_event.html_link == "some updated html_link"
      assert calendar_event.hangout_link == "some updated hangout_link"
      assert calendar_event.start_time == ~U[2025-05-24 19:00:00Z]
      assert calendar_event.end_time == ~U[2025-05-24 19:00:00Z]
      assert calendar_event.record_meeting == false
    end

    test "update_calendar_event/2 with invalid data returns error changeset" do
      calendar_event = calendar_event_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Calendar.update_calendar_event(calendar_event, @invalid_attrs)

      assert calendar_event == Calendar.get_calendar_event!(calendar_event.id)
    end

    test "delete_calendar_event/1 deletes the calendar_event" do
      calendar_event = calendar_event_fixture()
      assert {:ok, %CalendarEvent{}} = Calendar.delete_calendar_event(calendar_event)
      assert_raise Ecto.NoResultsError, fn -> Calendar.get_calendar_event!(calendar_event.id) end
    end

    test "change_calendar_event/1 returns a calendar_event changeset" do
      calendar_event = calendar_event_fixture()
      assert %Ecto.Changeset{} = Calendar.change_calendar_event(calendar_event)
    end

    test "create_or_update_calendar_event/1 creates or updates a calendar event" do
      user = user_fixture()
      user_credential = user_credential_fixture(%{user_id: user.id})

      valid_attrs = %{
        status: "some status",
        description: "some description",
        location: "some location",
        google_event_id: "some google_event_id",
        summary: "some summary",
        html_link: "some html_link",
        hangout_link: "some hangout_link",
        start_time: ~U[2025-05-23 19:00:00Z],
        end_time: ~U[2025-05-23 19:00:00Z],
        user_id: user.id,
        user_credential_id: user_credential.id
      }

      assert {:ok, %CalendarEvent{} = calendar_event} =
               Calendar.create_or_update_calendar_event(valid_attrs)

      assert Calendar.get_calendar_event!(calendar_event.id).summary == "some summary"

      updated_attrs = %{
        status: "some status",
        description: "some description",
        location: "some location",
        google_event_id: "some google_event_id",
        summary: "some updated summary",
        html_link: "some html_link",
        hangout_link: "some hangout_link",
        start_time: ~U[2025-05-23 19:00:00Z],
        end_time: ~U[2025-05-23 19:00:00Z],
        user_id: user.id,
        user_credential_id: user_credential.id
      }

      assert {:ok, %CalendarEvent{}} = Calendar.create_or_update_calendar_event(updated_attrs)
      assert Calendar.get_calendar_event!(calendar_event.id).summary == "some updated summary"
    end
  end
end
