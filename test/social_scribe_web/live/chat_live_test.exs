defmodule SocialScribeWeb.ChatLiveTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mox
  import SocialScribe.AccountsFixtures
  import SocialScribe.ChatFixtures

  setup :verify_on_exit!

  describe "Chat page mounting" do
    test "successful mount with CRM connected", %{conn: conn} do
      user = user_fixture()
      _hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})

      {:ok, view, html} = live(log_in_user(conn, user), ~p"/dashboard/chat")

      assert html =~ "Ask Anything"

      assert has_element?(
               view,
               "div[contenteditable=true][data-placeholder*='Ask anything about your meetings']"
             )

      assert has_element?(view, "form[phx-submit='send_message']")
    end

    test "mount without CRM credentials shows appropriate messaging", %{conn: conn} do
      user = user_fixture()
      # No credentials created

      {:ok, _view, html} = live(log_in_user(conn, user), ~p"/dashboard/chat")

      assert html =~ "No CRM connected"
      assert html =~ "Connect HubSpot or Salesforce"
    end

    test "loads recent messages on mount", %{conn: conn} do
      user = user_fixture()
      _hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})

      # Create some messages
      _user_msg = user_message_fixture(user.id, %{content: "Previous question"})
      _assistant_msg = assistant_message_fixture(user.id, %{content: "Previous answer"})

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/dashboard/chat")

      # Verify messages are displayed
      assert render(view) =~ "Previous question"
      assert render(view) =~ "Previous answer"
    end
  end

  describe "Contact search" do
    setup %{conn: conn} do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})

      %{
        conn: log_in_user(conn, user),
        user: user,
        hubspot_credential: hubspot_credential
      }
    end

    test "HubSpot contact search displays results", %{conn: conn} do
      mock_contacts = [
        %{
          id: "123",
          firstname: "John",
          lastname: "Doe",
          email: "john@example.com",
          display_name: "John Doe",
          source: "hubspot",
          company: ""
        }
      ]

      SocialScribe.HubspotApiMock
      |> expect(:search_contacts, fn _credential, "John" ->
        {:ok, mock_contacts}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      # Open modal first
      view
      |> element("button[phx-click='open_contact_search']")
      |> render_click()

      # Trigger search
      view
      |> element("input[phx-keyup='search_contacts']")
      |> render_keyup(%{"value" => "John"})

      :timer.sleep(200)

      html = render(view)
      assert html =~ "John Doe"
      assert html =~ "john@example.com"
    end

    test "search with less than 2 characters does not trigger API call", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      # Open modal first
      view
      |> element("button[phx-click='open_contact_search']")
      |> render_click()

      # Should not trigger any API calls
      view
      |> element("input[phx-keyup='search_contacts']")
      |> render_keyup(%{"value" => "J"})

      # No expect defined, so if API was called, test would fail
      :timer.sleep(100)

      # Just verify the modal is still open
      assert has_element?(view, "input[phx-keyup='search_contacts']")
    end

    test "search API error handled gracefully", %{conn: conn} do
      SocialScribe.HubspotApiMock
      |> expect(:search_contacts, fn _credential, _query ->
        {:error, {:api_error, 500, %{"message" => "Server error"}}}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      # Open modal first
      view
      |> element("button[phx-click='open_contact_search']")
      |> render_click()

      view
      |> element("input[phx-keyup='search_contacts']")
      |> render_keyup(%{"value" => "Test"})

      :timer.sleep(200)

      # Should not crash - modal should still be open
      assert has_element?(view, "input[phx-keyup='search_contacts']")
    end

    test "@mention in textarea triggers mention search", %{conn: conn} do
      mock_contacts = [
        %{
          id: "456",
          firstname: "Alice",
          lastname: "Smith",
          email: "alice@example.com",
          display_name: "Alice Smith",
          source: "hubspot",
          company: ""
        }
      ]

      SocialScribe.HubspotApiMock
      |> expect(:search_contacts, fn _credential, "Ali" ->
        {:ok, mock_contacts}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      # Simulate typing @mention via the sync_mentions hook
      # This is what the JavaScript hook sends when user types "@Ali"
      view
      |> render_hook("sync_mentions", %{
        "message" => "What is the email of @Alice",
        "mentions" => ["Alice"]
      })

      # Trigger mention search
      view
      |> render_hook("mention_search", %{"query" => "Ali"})

      :timer.sleep(200)

      # The mention dropdown should show results
      html = render(view)
      assert html =~ "Alice Smith"
      assert html =~ "alice@example.com"
    end
  end

  describe "Contact selection and tagging" do
    setup %{conn: conn} do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})

      %{
        conn: log_in_user(conn, user),
        user: user,
        hubspot_credential: hubspot_credential
      }
    end

    test "selecting contact from search results adds to tagged contacts", %{
      conn: conn,
      user: user
    } do
      mock_contact = %{
        id: "123",
        firstname: "John",
        lastname: "Doe",
        email: "john@example.com",
        source: "hubspot",
        display_name: "John Doe"
      }

      SocialScribe.HubspotApiMock
      |> expect(:search_contacts, fn _credential, _query ->
        {:ok, [mock_contact]}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      # Open contact search modal
      view
      |> element("button[phx-click='open_contact_search']")
      |> render_click()

      # Search
      view
      |> element("input[phx-keyup='search_contacts']")
      |> render_keyup(%{"value" => "John"})

      :timer.sleep(200)

      # Select contact using add_context_contact
      view
      |> element("button[data-testid='add-context-contact-button']")
      |> render_click(%{
        "id" => "123",
        "source" => "hubspot",
        "firstname" => "John",
        "lastname" => "Doe",
        "email" => "john@example.com",
        "company" => "",
        "display_name" => "John Doe"
      })

      html = render(view)
      assert html =~ "John Doe"
    end

    @tag :skip
    test "removing tagged contact", %{conn: conn, user: user} do
      # Skip this test - remove_contact UI button not implemented yet
      # The feature exists in the backend but has no UI
    end

    test "duplicate contact prevention", %{conn: conn, user: user} do
      mock_contact = %{
        id: "123",
        firstname: "John",
        lastname: "Doe",
        email: "john@example.com",
        source: "hubspot",
        display_name: "John Doe"
      }

      SocialScribe.HubspotApiMock
      |> expect(:search_contacts, 2, fn _credential, _query ->
        {:ok, [mock_contact]}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      # Add contact first time
      view
      |> element("button[phx-click='open_contact_search']")
      |> render_click()

      view
      |> element("input[phx-keyup='search_contacts']")
      |> render_keyup(%{"value" => "John"})

      :timer.sleep(200)

      view
      |> element("button[data-testid='add-context-contact-button']")
      |> render_click(%{
        "id" => "123",
        "source" => "hubspot",
        "firstname" => "John",
        "lastname" => "Doe",
        "email" => "john@example.com",
        "company" => "",
        "display_name" => "John Doe"
      })

      # Try to add same contact again - reopen modal
      view
      |> element("button[phx-click='open_contact_search']")
      |> render_click()

      view
      |> element("input[phx-keyup='search_contacts']")
      |> render_keyup(%{"value" => "John"})

      :timer.sleep(200)

      view
      |> element("button[data-testid='add-context-contact-button']")
      |> render_click(%{
        "id" => "123",
        "source" => "hubspot",
        "firstname" => "John",
        "lastname" => "Doe",
        "email" => "john@example.com",
        "company" => "",
        "display_name" => "John Doe"
      })

      # Modal closes after adding, reopen to verify count
      view
      |> element("button[phx-click='open_contact_search']")
      |> render_click()

      # Should show "Selected: 1 contacts" in the modal
      html = render(view)
      assert html =~ "Selected: 1 contacts"
    end
  end

  describe "Message validation" do
    setup %{conn: conn} do
      user = user_fixture()
      _hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})

      %{conn: log_in_user(conn, user)}
    end

    test "validation: empty message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      # Try to send empty message
      view
      |> element("form[phx-submit='send_message']")
      |> render_submit(%{})

      # Should show error flash
      assert render(view) =~ "Please enter a message"
    end

    test "validation: no contacts tagged", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      # First set a message via sync_mentions event (simulating JS input)
      view
      |> render_hook("sync_mentions", %{"message" => "Test message", "mentions" => []})

      # Try to send message without contacts
      view
      |> element("form[phx-submit='send_message']")
      |> render_submit(%{})

      # Should show error
      assert render(view) =~ "Please tag at least one contact"
    end
  end

  describe "AI response handling" do
    setup %{conn: conn} do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})

      %{
        conn: log_in_user(conn, user),
        user: user,
        hubspot_credential: hubspot_credential
      }
    end

    test "successful AI response displayed", %{conn: conn, user: user} do
      # Setup mocks
      mock_contact = %{
        id: "123",
        firstname: "John",
        lastname: "Doe",
        email: "john@example.com",
        source: "hubspot",
        display_name: "John Doe",
        company: ""
      }

      # Mock search to return contact
      SocialScribe.HubspotApiMock
      |> expect(:search_contacts, fn _credential, _query ->
        {:ok, [mock_contact]}
      end)

      # Mock get_contact to return full details
      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _credential, _id ->
        {:ok,
         %{id: "123", firstname: "John", email: "john@example.com", display_name: "John Doe"}}
      end)

      # Mock AI generation
      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_query_response, fn _question, _context ->
        {:ok, "John's email is john@example.com"}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/chat")

      # Step 1: Open contact search modal
      view
      |> element("button[phx-click='open_contact_search']")
      |> render_click()

      # Step 2: Search for contact
      view
      |> element("input[phx-keyup='search_contacts']")
      |> render_keyup(%{"value" => "John"})

      :timer.sleep(200)

      # Step 3: Select contact - this adds to selected_contacts AND updates message_input
      view
      |> element("button[data-testid='add-context-contact-button']")
      |> render_click(%{
        "id" => "123",
        "source" => "hubspot",
        "firstname" => "John",
        "lastname" => "Doe",
        "email" => "john@example.com",
        "company" => "",
        "display_name" => "John Doe"
      })

      # Step 4: Update message with full question (add_context_contact adds "@John ")
      # Note: We need to sync the full message including the mention
      view
      |> render_hook("sync_mentions", %{
        "message" => "@John What is your email?",
        "mentions" => ["John"]
      })

      :timer.sleep(100)

      # Step 5: Submit message - this triggers async AI processing
      view
      |> element("form[phx-submit='send_message']")
      |> render_submit(%{})

      # Step 6: Wait for async processing and re-render
      # The AI response is handled via handle_info which updates the socket
      :timer.sleep(1500)

      # Re-render to get updated HTML
      html = render(view)

      # Step 7: Assert AI response appears
      # The response should appear as an assistant message
      # Note: Apostrophes are HTML-encoded as &#39; in the rendered HTML
      assert html =~ "john@example.com"
    end
  end
end
