defmodule SocialScribeWeb.UserSettingsLiveTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures

  describe "UserSettingsLive" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "redirects if user is not logged in", %{conn: conn} do
      conn = recycle(conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard/settings")
      assert path == ~p"/users/log_in"
    end

    test "renders settings page for logged-in user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      assert has_element?(view, "h1", "User Settings")
      assert has_element?(view, "h2", "Connected Google Accounts")
      assert has_element?(view, "a", "Connect another Google Account")
    end

    test "displays a message if no Google accounts are connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")
      assert has_element?(view, "p", "You haven't connected any Google accounts yet.")
    end

    test "displays connected Google accounts", %{conn: conn, user: user} do
      # Create a Google credential for the user
      # Assuming UserCredential has an :email field for display purposes.
      # If not, you might display the UID or another identifier.
      credential_attrs = %{
        user_id: user.id,
        provider: "google",
        uid: "google-uid-123",
        token: "test-token",
        email: "linked_account@example.com"
      }

      _credential = user_credential_fixture(credential_attrs)

      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      assert has_element?(view, "li", "UID: google-uid-123")
      assert has_element?(view, "li", "(linked_account@example.com)")
      refute has_element?(view, "p", "You haven't connected any Google accounts yet.")
    end
  end
end
