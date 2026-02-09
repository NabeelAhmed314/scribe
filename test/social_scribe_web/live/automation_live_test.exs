defmodule SocialScribeWeb.AutomationLiveTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AutomationsFixtures
  import SocialScribe.AccountsFixtures

  @create_attrs %{
    name: "some name <> #{System.unique_integer()}",
    description: "some description",
    platform: :facebook,
    example: "some example"
  }
  @update_attrs %{
    name: "some updated name",
    description: "some updated description",
    platform: :facebook,
    example: "some updated example"
  }
  @invalid_attrs %{
    name: nil,
    description: nil,
    platform: :linkedin,
    example: nil
  }

  defp create_automation(%{conn: conn}) do
    user = user_fixture()
    automation = automation_fixture(%{user_id: user.id, is_active: false})

    %{conn: log_in_user(conn, user), automation: automation}
  end

  describe "Index" do
    setup [:create_automation]

    test "lists all automations", %{conn: conn, automation: automation} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/automations")

      assert html =~ "Listing Automations"
      assert html =~ automation.name
    end

    test "saves new automation", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations")

      assert index_live |> element("a", "New Automation") |> render_click() =~
               "New Automation"

      assert_patch(index_live, ~p"/dashboard/automations/new")

      assert index_live
             |> form("#automation-form", automation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#automation-form", automation: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/dashboard/automations")

      html = render(index_live)
      assert html =~ "Automation created successfully"
      assert html =~ "some description"
    end

    test "cannot toggle automation if it is already active", %{conn: conn, automation: automation} do
      _automation_2 =
        automation_fixture(%{
          user_id: automation.user_id,
          platform: automation.platform,
          is_active: true
        })

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations")

      assert index_live
             |> element("#automations-#{automation.id} input[phx-click='toggle_automation']")
             |> render_click() =~ "You can only have one active automation per platform"
    end

    test "updates automation in listing", %{conn: conn, automation: automation} do
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations")

      assert index_live |> element("#automations-#{automation.id} a", "Edit") |> render_click() =~
               "Edit Automation"

      assert_patch(index_live, ~p"/dashboard/automations/#{automation}/edit")

      assert index_live
             |> form("#automation-form", automation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#automation-form", automation: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/dashboard/automations")

      html = render(index_live)
      assert html =~ "Automation updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes automation in listing", %{conn: conn, automation: automation} do
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations")

      assert index_live |> element("#automations-#{automation.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#automations-#{automation.id}")
    end
  end

  describe "Show" do
    setup [:create_automation]

    test "displays automation", %{conn: conn, automation: automation} do
      {:ok, _show_live, html} = live(conn, ~p"/dashboard/automations/#{automation}")

      assert html =~ "Show Automation"
      assert html =~ automation.name
    end

    test "cannot toggle automation if it is already active", %{conn: conn, automation: automation} do
      _automation_2 =
        automation_fixture(%{
          user_id: automation.user_id,
          platform: automation.platform,
          is_active: true
        })

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations/#{automation}")

      assert index_live
             |> element("input[phx-click='toggle_automation']")
             |> render_click() =~ "You can only have one active automation per platform"
    end

    test "updates automation within modal", %{conn: conn, automation: automation} do
      {:ok, show_live, _html} = live(conn, ~p"/dashboard/automations/#{automation}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Automation"

      assert_patch(show_live, ~p"/dashboard/automations/#{automation}/show/edit")

      assert show_live
             |> form("#automation-form", automation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#automation-form", automation: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/dashboard/automations/#{automation}")

      html = render(show_live)
      assert html =~ "Automation updated successfully"
      assert html =~ "some updated name"
    end
  end
end
