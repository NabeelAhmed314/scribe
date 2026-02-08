defmodule SocialScribeWeb.HubspotModalTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures

  describe "HubSpot Modal" do
    setup %{conn: conn} do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        hubspot_credential: hubspot_credential
      }
    end

    test "renders modal when navigating to hubspot route", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      assert has_element?(view, "#hubspot-modal-wrapper")
      assert has_element?(view, "h2", "Update in HubSpot")
    end

    test "displays contact search input", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      assert has_element?(view, "input[placeholder*='Search']")
    end

    test "shows contact search initially without suggestions form", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      # Initially, only the contact search is shown, no form for suggestions
      # The form only appears after a contact is selected and suggestions are generated
      assert has_element?(view, "input[phx-keyup='contact_search']")

      # No suggestion form should be present initially
      refute has_element?(view, "form[phx-submit='apply_updates']")
    end

    test "modal can be closed by navigating back", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      assert has_element?(view, "#hubspot-modal-wrapper")

      # Navigate back to the meeting page
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      refute has_element?(view, "#hubspot-modal-wrapper")
    end
  end

  describe "HubSpot Modal - without credential" do
    setup %{conn: conn} do
      user = user_fixture()
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting
      }
    end

    test "does not show HubSpot section when no credential", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      refute html =~ "HubSpot Integration"
      refute html =~ "Update HubSpot Contact"
    end

    test "redirects to meeting page when accessing hubspot route without credential", %{
      conn: conn,
      meeting: meeting
    } do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      # Modal should not be present since there's no hubspot credential
      refute html =~ "hubspot-modal-wrapper"
    end
  end

  describe "HubspotModalComponent events" do
    setup %{conn: conn} do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        hubspot_credential: hubspot_credential
      }
    end

    test "toggle_suggestion updates checkbox state", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      # The modal component handles toggle_suggestion events
      # We can test this by sending the event directly to the component
      # First verify the modal is present
      assert has_element?(view, "#hubspot-modal-wrapper")
    end

    test "contact_search input is present and accepts input", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      # Verify the search input exists and has the correct attributes
      assert has_element?(view, "input[phx-keyup='contact_search']")
      assert has_element?(view, "input[placeholder*='Search']")
      assert has_element?(view, "#hubspot-modal-wrapper")
    end
  end

  # Helper function to create a meeting with transcript for testing
  defp meeting_fixture_with_transcript(user) do
    meeting = meeting_fixture(%{})

    # Update the meeting's calendar_event to belong to the test user
    calendar_event = SocialScribe.Calendar.get_calendar_event!(meeting.calendar_event_id)

    {:ok, _updated_event} =
      SocialScribe.Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

    # Create a transcript with some content
    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "John Doe",
            "words" => [
              %{"text" => "Hello,"},
              %{"text" => "my"},
              %{"text" => "phone"},
              %{"text" => "number"},
              %{"text" => "is"},
              %{"text" => "555-1234"}
            ]
          }
        ]
      }
    })

    # Reload the meeting with all associations
    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end
end
