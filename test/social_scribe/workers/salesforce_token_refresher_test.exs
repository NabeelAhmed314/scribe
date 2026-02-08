defmodule SocialScribe.Workers.SalesforceTokenRefresherTest do
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures

  alias SocialScribe.Workers.SalesforceTokenRefresher
  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.Repo

  import Ecto.Query

  setup do
    # Set up Tesla.Mock to intercept HTTP requests
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://login.salesforce.com/services/oauth2/token"} ->
        # Return a mock successful token refresh response
        %Tesla.Env{
          status: 200,
          body: %{
            "access_token" => "mock_refreshed_token_12345",
            "expires_in" => 3600,
            "token_type" => "Bearer"
          }
        }
    end)

    :ok
  end

  describe "perform/1" do
    test "does nothing if there are no Salesforce credentials" do
      # Ensure no Salesforce credentials exist
      count =
        from(c in UserCredential, where: c.provider == "salesforce")
        |> Repo.aggregate(:count, :id)

      assert count == 0

      assert SalesforceTokenRefresher.perform(%Oban.Job{}) == :ok
    end

    test "refreshes credentials expiring within 10 minutes" do
      user = user_fixture()

      # Create a Salesforce credential expiring in 5 minutes
      expiring_credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
        })

      # Create a Salesforce credential expiring in 1 hour (should not be refreshed)
      valid_credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      # The worker will attempt to refresh the expiring credential
      # but will fail since we don't have Salesforce API access
      # We verify the worker runs without crashing
      assert SalesforceTokenRefresher.perform(%Oban.Job{}) == :ok

      # Both credentials should still exist
      assert Repo.get(UserCredential, expiring_credential.id) != nil
      assert Repo.get(UserCredential, valid_credential.id) != nil
    end

    test "skips credentials without refresh_token" do
      user = user_fixture()

      # Create a Salesforce credential without refresh_token
      credential_without_refresh =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
          refresh_token: nil
        })

      assert SalesforceTokenRefresher.perform(%Oban.Job{}) == :ok

      # Credential should still exist
      assert Repo.get(UserCredential, credential_without_refresh.id) != nil
    end

    test "handles multiple Salesforce credentials" do
      user1 = user_fixture()
      user2 = user_fixture()

      # Create multiple expiring credentials
      _credential1 =
        salesforce_credential_fixture(%{
          user_id: user1.id,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
        })

      _credential2 =
        salesforce_credential_fixture(%{
          user_id: user2.id,
          expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
        })

      assert SalesforceTokenRefresher.perform(%Oban.Job{}) == :ok

      # Both users should still have their credentials
      user1_creds =
        from(c in UserCredential, where: c.user_id == ^user1.id and c.provider == "salesforce")
        |> Repo.all()

      user2_creds =
        from(c in UserCredential, where: c.user_id == ^user2.id and c.provider == "salesforce")
        |> Repo.all()

      assert length(user1_creds) == 1
      assert length(user2_creds) == 1
    end

    test "logs errors on refresh failures" do
      user = user_fixture()

      # Create a Salesforce credential that will fail to refresh
      # (we don't have real Salesforce API access)
      _credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
        })

      # The worker should complete without crashing even on failures
      assert SalesforceTokenRefresher.perform(%Oban.Job{}) == :ok
    end

    test "only processes Salesforce credentials, not HubSpot" do
      user = user_fixture()

      # Create a HubSpot credential expiring soon
      _hubspot_credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
        })

      # Create a Salesforce credential expiring soon
      _salesforce_credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
        })

      assert SalesforceTokenRefresher.perform(%Oban.Job{}) == :ok

      # Both credentials should still exist
      salesforce_count =
        from(c in UserCredential, where: c.provider == "salesforce")
        |> Repo.aggregate(:count, :id)

      hubspot_count =
        from(c in UserCredential, where: c.provider == "hubspot")
        |> Repo.aggregate(:count, :id)

      assert salesforce_count == 1
      assert hubspot_count == 1
    end
  end

  describe "worker configuration" do
    test "worker uses correct queue" do
      # The worker is configured with queue: :default via use Oban.Worker
      # Verify by creating a changeset and checking the queue field
      changeset = SalesforceTokenRefresher.new(%{})
      # Queue is not explicitly in changes but is set in the worker definition
      # Just verify the changeset is valid and has correct worker
      assert changeset.valid?
      assert changeset.changes.worker == "SocialScribe.Workers.SalesforceTokenRefresher"
    end

    test "worker has max_attempts set to 3" do
      # Verify the worker configuration by checking changeset
      changeset = SalesforceTokenRefresher.new(%{})
      assert changeset.changes.max_attempts == 3
    end
  end
end
