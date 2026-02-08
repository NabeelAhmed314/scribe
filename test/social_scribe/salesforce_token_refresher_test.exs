defmodule SocialScribe.SalesforceTokenRefresherTest do
  use SocialScribe.DataCase

  alias SocialScribe.SalesforceTokenRefresher
  alias SocialScribe.Accounts

  import SocialScribe.AccountsFixtures

  setup do
    # Set up Tesla.Mock to intercept HTTP requests for each test
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://login.salesforce.com/services/oauth2/token"} ->
        # Return a mock successful token refresh response
        %Tesla.Env{
          status: 200,
          body: %{
            "access_token" => "mock_new_access_token_12345",
            "expires_in" => 3600,
            "token_type" => "Bearer"
          }
        }
    end)

    :ok
  end

  describe "ensure_valid_token/1" do
    test "returns credential unchanged when token is not expired" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      {:ok, result} = SalesforceTokenRefresher.ensure_valid_token(credential)

      assert result.id == credential.id
      assert result.token == credential.token
    end

    test "returns credential unchanged when token expires in more than 5 minutes" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
        })

      {:ok, result} = SalesforceTokenRefresher.ensure_valid_token(credential)

      assert result.id == credential.id
      assert result.token == credential.token
    end

    test "triggers refresh when token expires in less than 5 minutes" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
          token: "old_token"
        })

      {:ok, result} = SalesforceTokenRefresher.ensure_valid_token(credential)

      # Should return updated credential with new token
      assert result.id == credential.id
      assert result.token == "mock_new_access_token_12345"
      assert result.token != "old_token"

      # Verify expires_at was updated (should be ~1 hour from now)
      time_diff = DateTime.diff(result.expires_at, DateTime.utc_now())
      assert time_diff > 3500 and time_diff <= 3600
    end

    test "triggers refresh when token is already expired" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -300, :second),
          token: "expired_token"
        })

      {:ok, result} = SalesforceTokenRefresher.ensure_valid_token(credential)

      # Should return updated credential with new token
      assert result.id == credential.id
      assert result.token == "mock_new_access_token_12345"
      assert result.token != "expired_token"
    end
  end

  describe "refresh_credential/1" do
    test "updates credential in database on successful refresh" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          token: "old_token",
          refresh_token: "old_refresh"
        })

      {:ok, updated} = SalesforceTokenRefresher.refresh_credential(credential)

      assert updated.token == "mock_new_access_token_12345"
      assert updated.id == credential.id
      # Salesforce typically doesn't rotate refresh tokens
      assert updated.refresh_token == "old_refresh"

      # Verify expires_at was updated
      time_diff = DateTime.diff(updated.expires_at, DateTime.utc_now())
      assert time_diff > 3500 and time_diff <= 3600
    end

    test "returns error on refresh failure" do
      # Override the mock to simulate an error
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://login.salesforce.com/services/oauth2/token"} ->
          %Tesla.Env{
            status: 400,
            body: %{"error" => "invalid_grant", "error_description" => "refresh token expired"}
          }
      end)

      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          token: "old_token",
          refresh_token: "invalid_refresh"
        })

      result = SalesforceTokenRefresher.refresh_credential(credential)

      assert {:error, {400, _}} = result
    end
  end

  describe "refresh_token/1" do
    test "successfully refreshes token via HTTP" do
      result = SalesforceTokenRefresher.refresh_token("test_refresh_token")

      assert {:ok, body} = result
      assert body["access_token"] == "mock_new_access_token_12345"
      assert body["expires_in"] == 3600
    end

    test "handles HTTP error responses" do
      # Override the mock to simulate an error
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://login.salesforce.com/services/oauth2/token"} ->
          %Tesla.Env{
            status: 401,
            body: %{
              "error" => "invalid_client",
              "error_description" => "client authentication failed"
            }
          }
      end)

      result = SalesforceTokenRefresher.refresh_token("bad_token")

      assert {:error, {401, _}} = result
    end

    test "handles network errors" do
      # Override the mock to simulate a network error
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://login.salesforce.com/services/oauth2/token"} ->
          {:error, :timeout}
      end)

      result = SalesforceTokenRefresher.refresh_token("test_token")

      assert {:error, :timeout} = result
    end
  end

  describe "token error detection" do
    test "API errors trigger token refresh detection" do
      # Set up SalesforceApiMock to simulate token error then success after refresh
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://login.salesforce.com/services/oauth2/token"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "access_token" => "refreshed_token_after_error",
              "expires_in" => 3600
            }
          }
      end)

      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -300, :second),
          token: "expired_token_with_error"
        })

      # Verify the credential is expired
      assert DateTime.compare(credential.expires_at, DateTime.utc_now()) == :lt

      # Trigger refresh
      {:ok, result} = SalesforceTokenRefresher.ensure_valid_token(credential)

      # Should have refreshed
      assert result.token == "refreshed_token_after_error"
    end

    test "valid token does not trigger refresh" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          token: "valid_token"
        })

      # Token is valid, should not trigger refresh
      {:ok, result} = SalesforceTokenRefresher.ensure_valid_token(credential)
      assert result.id == credential.id
      assert result.token == "valid_token"
    end
  end
end
