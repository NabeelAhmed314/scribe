defmodule SocialScribe.BotsTest do
  use SocialScribe.DataCase

  alias SocialScribe.Bots

  import SocialScribe.CalendarFixtures
  import SocialScribe.AccountsFixtures

  describe "recall_bots" do
    alias SocialScribe.Bots.RecallBot

    import SocialScribe.BotsFixtures

    @invalid_attrs %{status: nil, recall_bot_id: nil, meeting_url: nil}

    test "list_recall_bots/0 returns all recall_bots" do
      recall_bot = recall_bot_fixture()
      assert Bots.list_recall_bots() == [recall_bot]
    end

    test "list_pending_bots/0 returns all pending recall_bots" do
      recall_bot = recall_bot_fixture(%{status: "ready"})
      _recall_bot2 = recall_bot_fixture(%{status: "error"})
      _recall_bot3 = recall_bot_fixture(%{status: "done"})

      assert Bots.list_pending_bots() == [recall_bot]
    end

    test "get_recall_bot!/1 returns the recall_bot with given id" do
      recall_bot = recall_bot_fixture()
      assert Bots.get_recall_bot!(recall_bot.id) == recall_bot
    end

    test "create_recall_bot/1 with valid data creates a recall_bot" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})

      valid_attrs = %{
        status: "some status",
        recall_bot_id: "some recall_bot_id",
        meeting_url: "some meeting_url",
        user_id: user.id,
        calendar_event_id: calendar_event.id
      }

      assert {:ok, %RecallBot{} = recall_bot} = Bots.create_recall_bot(valid_attrs)
      assert recall_bot.status == "some status"
      assert recall_bot.recall_bot_id == "some recall_bot_id"
      assert recall_bot.meeting_url == "some meeting_url"
    end

    test "create_recall_bot/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Bots.create_recall_bot(@invalid_attrs)
    end

    test "update_recall_bot/2 with valid data updates the recall_bot" do
      recall_bot = recall_bot_fixture()

      update_attrs = %{
        status: "some updated status",
        recall_bot_id: "some updated recall_bot_id",
        meeting_url: "some updated meeting_url"
      }

      assert {:ok, %RecallBot{} = recall_bot} = Bots.update_recall_bot(recall_bot, update_attrs)
      assert recall_bot.status == "some updated status"
      assert recall_bot.recall_bot_id == "some updated recall_bot_id"
      assert recall_bot.meeting_url == "some updated meeting_url"
    end

    test "update_recall_bot/2 with invalid data returns error changeset" do
      recall_bot = recall_bot_fixture()
      assert {:error, %Ecto.Changeset{}} = Bots.update_recall_bot(recall_bot, @invalid_attrs)
      assert recall_bot == Bots.get_recall_bot!(recall_bot.id)
    end

    test "delete_recall_bot/1 deletes the recall_bot" do
      recall_bot = recall_bot_fixture()
      assert {:ok, %RecallBot{}} = Bots.delete_recall_bot(recall_bot)
      assert_raise Ecto.NoResultsError, fn -> Bots.get_recall_bot!(recall_bot.id) end
    end

    test "change_recall_bot/1 returns a recall_bot changeset" do
      recall_bot = recall_bot_fixture()
      assert %Ecto.Changeset{} = Bots.change_recall_bot(recall_bot)
    end
  end

  describe "orchestration" do
    alias SocialScribe.Bots.RecallBot
    alias SocialScribe.RecallApiMock

    import SocialScribe.BotsFixtures
    import Mox

    setup do
      stub_with(RecallApiMock, SocialScribe.Recall)
      :ok
    end

    test "create_and_dispatch_bot/2 creates a bot via API and saves to database" do
      user = user_fixture()

      calendar_event = calendar_event_fixture(%{user_id: user.id})

      # Mock successful API response
      expect(RecallApiMock, :create_bot, fn _meeting_url, start_time ->
        assert start_time == DateTime.add(calendar_event.start_time, -2, :minute)

        {:ok,
         %{
           status: 200,
           body: %{
             id: "recall_bot_123",
             video_url: nil,
             status_changes: [
               %{
                 code: "ready",
                 message: nil,
                 created_at: "2023-03-23T18:59:40.391872Z"
               }
             ],
             meeting_metadata: nil,
             meeting_participants: [],
             speaker_timeline: %{
               timeline: []
             },
             calendar_meeting_id: nil,
             calendar_user_id: nil,
             calendar_meetings: []
           }
         }}
      end)

      assert {:ok, %RecallBot{} = bot} = Bots.create_and_dispatch_bot(user, calendar_event)
      assert bot.user_id == user.id
      assert bot.calendar_event_id == calendar_event.id
      assert bot.recall_bot_id == "recall_bot_123"
      assert bot.meeting_url == calendar_event.hangout_link
    end

    test "create_and_dispatch_bot/2 uses user_bot_preference join_minute_offset" do
      user = user_fixture()

      _user_bot_preference =
        user_bot_preference_fixture(%{user_id: user.id, join_minute_offset: 10})

      calendar_event = calendar_event_fixture(%{user_id: user.id})

      expect(RecallApiMock, :create_bot, fn _meeting_url, start_time ->
        assert start_time == DateTime.add(calendar_event.start_time, -10, :minute)

        {:ok,
         %{
           status: 200,
           body: %{
             id: "recall_bot_123",
             video_url: nil,
             status_changes: [
               %{
                 code: "ready",
                 message: nil,
                 created_at: "2023-03-23T18:59:40.391872Z"
               }
             ],
             meeting_metadata: nil,
             meeting_participants: [],
             speaker_timeline: %{
               timeline: []
             },
             calendar_meeting_id: nil,
             calendar_user_id: nil,
             calendar_meetings: []
           }
         }}
      end)

      assert {:ok, %RecallBot{} = bot} = Bots.create_and_dispatch_bot(user, calendar_event)
      assert bot.user_id == user.id
    end

    test "create_and_dispatch_bot/2 handles API errors" do
      user = user_fixture()

      calendar_event = calendar_event_fixture(%{user_id: user.id})

      # Mock API error
      expect(RecallApiMock, :create_bot, fn _meeting_url, _start_time ->
        {:error, "API Error"}
      end)

      assert {:error, {:api_error, "API Error"}} =
               Bots.create_and_dispatch_bot(user, calendar_event)
    end

    test "cancel_and_delete_bot/1 deletes bot via API and removes from database" do
      calendar_event = calendar_event_fixture()
      bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id})

      # Mock successful API response
      expect(RecallApiMock, :delete_bot, fn _bot_id ->
        {:ok, %{status: 200}}
      end)

      assert {:ok, %RecallBot{}} = Bots.cancel_and_delete_bot(calendar_event)
      assert_raise Ecto.NoResultsError, fn -> Bots.get_recall_bot!(bot.id) end
    end

    test "cancel_and_delete_bot/1 handles 404 API response" do
      calendar_event = calendar_event_fixture()
      bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id})

      # Mock 404 API response
      expect(RecallApiMock, :delete_bot, fn _bot_id ->
        {:ok, %{status: 404}}
      end)

      assert {:ok, %RecallBot{}} = Bots.cancel_and_delete_bot(calendar_event)
      assert_raise Ecto.NoResultsError, fn -> Bots.get_recall_bot!(bot.id) end
    end

    test "cancel_and_delete_bot/1 handles API errors" do
      calendar_event = calendar_event_fixture()
      bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id})

      expect(RecallApiMock, :delete_bot, fn _bot_id ->
        {:error, "API Error"}
      end)

      assert {:error, {:api_error, "API Error"}} = Bots.cancel_and_delete_bot(calendar_event)
      assert Bots.get_recall_bot!(bot.id) == bot
    end

    test "cancel_and_delete_bot/1 returns :no_bot_to_cancel when no bot exists" do
      calendar_event = calendar_event_fixture()
      assert {:ok, :no_bot_to_cancel} = Bots.cancel_and_delete_bot(calendar_event)
    end

    test "update_bot_schedule/2 updates bot schedule via API and saves to database" do
      calendar_event = calendar_event_fixture()
      bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id})

      expect(RecallApiMock, :update_bot, fn _bot_id, _meeting_url, start_time ->
        assert start_time == DateTime.add(calendar_event.start_time, -2, :minute)

        {:ok,
         %{
           body: %{
             id: "recall_bot_123",
             video_url: nil,
             status_changes: [
               %{
                 code: "ready",
                 message: nil,
                 created_at: "2023-03-23T18:59:40.391872Z"
               }
             ],
             meeting_metadata: nil,
             meeting_participants: [],
             speaker_timeline: %{
               timeline: []
             },
             calendar_meeting_id: nil,
             calendar_user_id: nil,
             calendar_meetings: []
           }
         }}
      end)

      assert {:ok, %RecallBot{} = updated_bot} = Bots.update_bot_schedule(bot, calendar_event)
      assert updated_bot.status == "ready"
    end

    test "update_bot_schedule/2 uses user_bot_preference join_minute_offset" do
      calendar_event = calendar_event_fixture()
      bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id})

      _user_bot_preference =
        user_bot_preference_fixture(%{user_id: bot.user_id, join_minute_offset: 10})

      expect(RecallApiMock, :update_bot, fn _bot_id, _meeting_url, start_time ->
        assert start_time == DateTime.add(calendar_event.start_time, -10, :minute)

        {:ok,
         %{
           body: %{
             id: "recall_bot_123",
             video_url: nil,
             status_changes: [
               %{
                 code: "ready",
                 message: nil,
                 created_at: "2023-03-23T18:59:40.391872Z"
               }
             ],
             meeting_metadata: nil,
             meeting_participants: [],
             speaker_timeline: %{
               timeline: []
             },
             calendar_meeting_id: nil,
             calendar_user_id: nil,
             calendar_meetings: []
           }
         }}
      end)

      assert {:ok, %RecallBot{} = updated_bot} = Bots.update_bot_schedule(bot, calendar_event)
      assert updated_bot.status == "ready"
    end

    test "update_bot_schedule/2 handles API errors" do
      calendar_event = calendar_event_fixture()
      bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id})

      # Mock API error
      expect(RecallApiMock, :update_bot, fn _bot_id, _meeting_url, _start_time ->
        {:error, "API Error"}
      end)

      assert {:error, "API Error"} = Bots.update_bot_schedule(bot, calendar_event)
    end
  end

  describe "user_bot_preferences" do
    alias SocialScribe.Bots.UserBotPreference

    import SocialScribe.BotsFixtures

    @invalid_attrs %{join_minute_offset: nil}

    test "list_user_bot_preferences/0 returns all user_bot_preferences" do
      user_bot_preference = user_bot_preference_fixture()
      assert Bots.list_user_bot_preferences() == [user_bot_preference]
    end

    test "get_user_bot_preference!/1 returns the user_bot_preference with given id" do
      user_bot_preference = user_bot_preference_fixture()
      assert Bots.get_user_bot_preference!(user_bot_preference.id) == user_bot_preference
    end

    test "create_user_bot_preference/1 with valid data creates a user_bot_preference" do
      user = user_fixture()
      valid_attrs = %{join_minute_offset: 1, user_id: user.id}

      assert {:ok, %UserBotPreference{} = user_bot_preference} =
               Bots.create_user_bot_preference(valid_attrs)

      assert user_bot_preference.join_minute_offset == 1
    end

    test "create_user_bot_preference/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Bots.create_user_bot_preference(@invalid_attrs)
    end

    test "update_user_bot_preference/2 with valid data updates the user_bot_preference" do
      user_bot_preference = user_bot_preference_fixture()
      update_attrs = %{join_minute_offset: 9}

      assert {:ok, %UserBotPreference{} = user_bot_preference} =
               Bots.update_user_bot_preference(user_bot_preference, update_attrs)

      assert user_bot_preference.join_minute_offset == 9
    end

    test "update_user_bot_preference/2 with invalid data returns error changeset" do
      user_bot_preference = user_bot_preference_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Bots.update_user_bot_preference(user_bot_preference, @invalid_attrs)

      assert user_bot_preference == Bots.get_user_bot_preference!(user_bot_preference.id)
    end

    test "delete_user_bot_preference/1 deletes the user_bot_preference" do
      user_bot_preference = user_bot_preference_fixture()
      assert {:ok, %UserBotPreference{}} = Bots.delete_user_bot_preference(user_bot_preference)

      assert_raise Ecto.NoResultsError, fn ->
        Bots.get_user_bot_preference!(user_bot_preference.id)
      end
    end

    test "change_user_bot_preference/1 returns a user_bot_preference changeset" do
      user_bot_preference = user_bot_preference_fixture()
      assert %Ecto.Changeset{} = Bots.change_user_bot_preference(user_bot_preference)
    end
  end
end
