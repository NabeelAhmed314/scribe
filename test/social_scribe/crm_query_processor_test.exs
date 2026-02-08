defmodule SocialScribe.CrmQueryProcessorTest do
  use SocialScribe.DataCase

  import Mox
  import SocialScribe.AccountsFixtures
  import SocialScribe.ChatFixtures

  alias SocialScribe.CrmQueryProcessor

  setup :verify_on_exit!

  describe "process_query/4" do
    setup do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential = salesforce_credential_fixture(%{user_id: user.id})

      %{
        user: user,
        hubspot_credential: hubspot_credential,
        salesforce_credential: salesforce_credential
      }
    end

    test "successful query processing with HubSpot contact", %{user: user} do
      selected_contacts = [
        %{id: "hubspot_123", source: "hubspot", display_name: "John Doe"}
      ]

      mock_contact = %{
        id: "hubspot_123",
        firstname: "John",
        lastname: "Doe",
        email: "john@example.com",
        phone: "555-1234",
        company: "Acme Corp",
        jobtitle: "Manager",
        display_name: "John Doe"
      }

      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _credential, "hubspot_123" ->
        {:ok, mock_contact}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_query_response, fn _question, context ->
        assert context.contacts != []
        assert context.question == "What is John's email?"
        {:ok, "John's email is john@example.com"}
      end)

      result = CrmQueryProcessor.process_query(user, "What is John's email?", selected_contacts)

      assert {:ok, "John's email is john@example.com"} = result
    end

    test "successful query processing with Salesforce contact", %{user: user} do
      selected_contacts = [
        %{id: "salesforce_456", source: "salesforce", display_name: "Jane Smith"}
      ]

      mock_contact = %{
        id: "salesforce_456",
        firstname: "Jane",
        lastname: "Smith",
        email: "jane@example.com",
        phone: "555-5678",
        company: "Tech Inc",
        jobtitle: "Director",
        display_name: "Jane Smith"
      }

      SocialScribe.SalesforceApiMock
      |> expect(:get_contact, fn _credential, "salesforce_456" ->
        {:ok, mock_contact}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_query_response, fn _question, context ->
        assert context.contacts != []
        {:ok, "Jane works at Tech Inc"}
      end)

      result = CrmQueryProcessor.process_query(user, "Where does Jane work?", selected_contacts)

      assert {:ok, "Jane works at Tech Inc"} = result
    end

    test "multi-contact query with both HubSpot and Salesforce", %{user: user} do
      selected_contacts = [
        %{id: "hubspot_123", source: "hubspot", display_name: "John Doe"},
        %{id: "salesforce_456", source: "salesforce", display_name: "Jane Smith"}
      ]

      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _credential, "hubspot_123" ->
        {:ok, %{id: "hubspot_123", firstname: "John", email: "john@example.com", display_name: "John Doe"}}
      end)

      SocialScribe.SalesforceApiMock
      |> expect(:get_contact, fn _credential, "salesforce_456" ->
        {:ok, %{id: "salesforce_456", firstname: "Jane", email: "jane@example.com", display_name: "Jane Smith"}}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_query_response, fn _question, context ->
        assert length(context.contacts) == 2
        {:ok, "John and Jane are both contacts"}
      end)

      result = CrmQueryProcessor.process_query(user, "Compare these contacts", selected_contacts)

      assert {:ok, "John and Jane are both contacts"} = result
    end

    test "query with conversation history", %{user: user} do
      # Create conversation history
      history = [
        %{type: "user", content: "What is John's email?"},
        %{type: "assistant", content: "John's email is john@example.com"}
      ]

      selected_contacts = [
        %{id: "hubspot_123", source: "hubspot", display_name: "John Doe"}
      ]

      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _credential, _id ->
        {:ok, %{id: "hubspot_123", firstname: "John", email: "john@example.com", display_name: "John Doe"}}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_query_response, fn _question, context ->
        assert context.conversation_history == history
        {:ok, "John's phone is 555-1234"}
      end)

      result = CrmQueryProcessor.process_query(user, "What about his phone?", selected_contacts, history)

      assert {:ok, "John's phone is 555-1234"} = result
    end

    test "error when no contacts can be retrieved", %{user: user} do
      selected_contacts = [
        %{id: "hubspot_123", source: "hubspot", display_name: "John Doe"}
      ]

      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _credential, _id ->
        {:error, :api_error}
      end)

      result = CrmQueryProcessor.process_query(user, "What is John's email?", selected_contacts)

      assert {:error, :no_contact_data_available} = result
    end

    test "error when AI generation fails", %{user: user} do
      selected_contacts = [
        %{id: "hubspot_123", source: "hubspot", display_name: "John Doe"}
      ]

      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _credential, _id ->
        {:ok, %{id: "hubspot_123", firstname: "John", display_name: "John Doe"}}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_query_response, fn _question, _context ->
        {:error, :ai_service_unavailable}
      end)

      result = CrmQueryProcessor.process_query(user, "What is John's email?", selected_contacts)

      assert {:error, :ai_generation_failed} = result
    end

    test "missing HubSpot credential handling" do
      # Create a user with ONLY Salesforce credential (no HubSpot)
      user_without_hubspot = user_fixture()
      _salesforce_credential = salesforce_credential_fixture(%{user_id: user_without_hubspot.id})
      # Intentionally NOT creating hubspot_credential_fixture

      selected_contacts = [
        %{id: "hubspot_123", source: "hubspot", display_name: "John Doe"}
      ]

      # No HubSpot mock setup - credential will be nil
      result = CrmQueryProcessor.process_query(user_without_hubspot, "What is John's email?", selected_contacts)

      # Should fail to retrieve contact data
      assert {:error, :no_contact_data_available} = result
    end
  end

  describe "retrieve_contact_details/2" do
    setup do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      salesforce_credential = salesforce_credential_fixture(%{user_id: user.id})

      %{
        user: user,
        hubspot_credential: hubspot_credential,
        salesforce_credential: salesforce_credential
      }
    end

    test "HubSpot contact retrieval with all fields", %{hubspot_credential: credential} do
      mock_contact = %{
        id: "123",
        firstname: "John",
        lastname: "Doe",
        email: "john@example.com",
        phone: "555-1234",
        mobilephone: "555-5678",
        company: "Acme Corp",
        jobtitle: "Manager",
        address: "123 Main St",
        city: "San Francisco",
        state: "CA",
        zip: "94102",
        country: "USA",
        website: "https://example.com",
        linkedin_url: "linkedin.com/in/johndoe",
        twitter_handle: "@johndoe",
        display_name: "John Doe"
      }

      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _cred, "123" ->
        {:ok, mock_contact}
      end)

      contact = %{id: "123", source: "hubspot"}
      result = CrmQueryProcessor.retrieve_contact_details(credential, contact)

      assert {:ok, formatted} = result
      assert formatted.source == "HubSpot"
      assert formatted.name == "John Doe"
      assert formatted.email == "john@example.com"
      assert formatted.phone == "555-1234"
      assert formatted.linkedin == "linkedin.com/in/johndoe"
    end

    test "Salesforce contact retrieval with field mapping", %{salesforce_credential: credential} do
      mock_contact = %{
        id: "456",
        firstname: "Jane",
        lastname: "Smith",
        email: "jane@example.com",
        phone: "555-9999",
        mobilephone: "555-8888",
        company: "Tech Inc",
        jobtitle: "Director",
        address: "456 Oak Ave",
        city: "New York",
        state: "NY",
        zip: "10001",
        country: "USA",
        display_name: "Jane Smith"
      }

      SocialScribe.SalesforceApiMock
      |> expect(:get_contact, fn _cred, "456" ->
        {:ok, mock_contact}
      end)

      contact = %{id: "456", source: "salesforce"}
      result = CrmQueryProcessor.retrieve_contact_details(credential, contact)

      assert {:ok, formatted} = result
      assert formatted.source == "Salesforce"
      assert formatted.name == "Jane Smith"
      assert formatted.email == "jane@example.com"
      assert formatted.job_title == "Director"
    end

    test "API error handling", %{hubspot_credential: credential} do
      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _cred, _id ->
        {:error, {:api_error, 500, %{"message" => "Internal error"}}}
      end)

      contact = %{id: "123", source: "hubspot"}
      result = CrmQueryProcessor.retrieve_contact_details(credential, contact)

      assert {:error, _} = result
    end

    test "unknown source handling", %{hubspot_credential: credential} do
      contact = %{id: "123", source: "unknown_crm"}
      result = CrmQueryProcessor.retrieve_contact_details(credential, contact)

      assert {:error, :unknown_source} = result
    end
  end
end
