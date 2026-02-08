defmodule SocialScribe.SalesforceSuggestionsTest do
  use SocialScribe.DataCase

  import Mox
  import SocialScribe.AccountsFixtures

  alias SocialScribe.SalesforceSuggestions

  setup :verify_on_exit!

  describe "merge_with_contact/2" do
    test "merges suggestions with contact data and filters unchanged values" do
      suggestions = [
        %{
          field: "Phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "Mentioned in call",
          apply: false,
          has_change: true
        },
        %{
          field: "Company",
          label: "Company",
          current_value: nil,
          new_value: "Acme Corp",
          context: "Works at Acme",
          apply: false,
          has_change: true
        }
      ]

      contact = %{
        id: "123",
        phone: nil,
        company: "Acme Corp",
        email: "test@example.com"
      }

      result = SalesforceSuggestions.merge_with_contact(suggestions, contact)

      # Only phone should remain since company already matches
      assert length(result) == 1
      assert hd(result).field == "Phone"
      assert hd(result).new_value == "555-1234"
    end

    test "returns empty list when all suggestions match current values" do
      suggestions = [
        %{
          field: "Email",
          label: "Email",
          current_value: nil,
          new_value: "test@example.com",
          context: "Email mentioned",
          apply: false,
          has_change: true
        }
      ]

      contact = %{
        id: "123",
        email: "test@example.com"
      }

      result = SalesforceSuggestions.merge_with_contact(suggestions, contact)

      assert result == []
    end

    test "handles empty suggestions list" do
      contact = %{id: "123", email: "test@example.com"}

      result = SalesforceSuggestions.merge_with_contact([], contact)

      assert result == []
    end
  end

  describe "field_labels" do
    test "common fields have human-readable labels" do
      suggestions = [
        %{
          field: "Phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "test",
          apply: false,
          has_change: true
        }
      ]

      contact = %{id: "123", phone: nil}

      result = SalesforceSuggestions.merge_with_contact(suggestions, contact)

      assert hd(result).label == "Phone"
    end

    test "Salesforce PascalCase fields map to correct labels" do
      suggestions = [
        %{
          field: "FirstName",
          label: "First Name",
          current_value: nil,
          new_value: "John",
          context: "test",
          apply: false,
          has_change: true
        },
        %{
          field: "LastName",
          label: "Last Name",
          current_value: nil,
          new_value: "Doe",
          context: "test",
          apply: false,
          has_change: true
        },
        %{
          field: "MobilePhone",
          label: "Mobile Phone",
          current_value: nil,
          new_value: "555-0000",
          context: "test",
          apply: false,
          has_change: true
        },
        %{
          field: "MailingCity",
          label: "City",
          current_value: nil,
          new_value: "San Francisco",
          context: "test",
          apply: false,
          has_change: true
        }
      ]

      contact = %{id: "123", firstname: nil, lastname: nil, mobilephone: nil, city: nil}

      result = SalesforceSuggestions.merge_with_contact(suggestions, contact)

      assert length(result) == 4
      assert Enum.any?(result, &(&1.field == "FirstName" and &1.label == "First Name"))
      assert Enum.any?(result, &(&1.field == "LastName" and &1.label == "Last Name"))
      assert Enum.any?(result, &(&1.field == "MobilePhone" and &1.label == "Mobile Phone"))
      assert Enum.any?(result, &(&1.field == "MailingCity" and &1.label == "City"))
    end
  end

  describe "generate_suggestions/3" do
    setup do
      user = user_fixture()
      credential = salesforce_credential_fixture(%{user_id: user.id})

      # Create a mock meeting
      meeting = %{
        id: 1,
        title: "Test Meeting",
        transcript: "John's phone is 555-1234 and he works at Acme Corp"
      }

      # Set up Tesla.Mock to intercept HTTP requests
      Tesla.Mock.mock(fn
        %{method: :get, url: url} ->
          if String.contains?(url, "/services/data/v") and
               String.contains?(url, "sobjects/Contact") do
            %Tesla.Env{
              status: 200,
              body: %{
                "Id" => "contact_123",
                "FirstName" => "John",
                "LastName" => "Doe",
                "Email" => "john@example.com",
                "Phone" => nil,
                "Company" => nil
              }
            }
          else
            %Tesla.Env{status: 404, body: %{"error" => "Not found"}}
          end
      end)

      %{user: user, credential: credential, meeting: meeting}
    end

    test "integrates with SalesforceApi.get_contact/2", %{
      credential: credential,
      meeting: meeting
    } do
      # Mock the AI content generator
      expect(SocialScribe.AIContentGeneratorMock, :generate_salesforce_suggestions, fn _meeting ->
        {:ok,
         [
           %{
             field: "Phone",
             value: "555-1234",
             context: "John's phone is 555-1234",
             timestamp: "01:23"
           },
           %{
             field: "Company",
             value: "Acme Corp",
             context: "he works at Acme Corp",
             timestamp: "02:45"
           }
         ]}
      end)

      result = SalesforceSuggestions.generate_suggestions(credential, "contact_123", meeting)

      assert {:ok, %{contact: _, suggestions: suggestions}} = result
      assert length(suggestions) == 2
      assert Enum.any?(suggestions, &(&1.field == "Phone"))
      assert Enum.any?(suggestions, &(&1.field == "Company"))
    end
  end

  describe "generate_suggestions_from_meeting/1" do
    test "works without contact data" do
      meeting = %{
        id: 1,
        title: "Test Meeting",
        transcript: "Contact info: john@example.com, phone 555-1234"
      }

      expect(SocialScribe.AIContentGeneratorMock, :generate_salesforce_suggestions, fn _meeting ->
        {:ok,
         [
           %{
             field: "Email",
             value: "john@example.com",
             context: "email mentioned",
             timestamp: "01:00"
           },
           %{field: "Phone", value: "555-1234", context: "phone mentioned", timestamp: "01:05"}
         ]}
      end)

      result = SalesforceSuggestions.generate_suggestions_from_meeting(meeting)

      assert {:ok, suggestions} = result
      assert length(suggestions) == 2
      assert hd(suggestions).field == "Email"
      assert hd(suggestions).new_value == "john@example.com"
      assert hd(suggestions).current_value == nil
      assert hd(suggestions).has_change == true
    end

    test "handles AI generation errors" do
      meeting = %{id: 1, title: "Test Meeting"}

      expect(SocialScribe.AIContentGeneratorMock, :generate_salesforce_suggestions, fn _meeting ->
        {:error, :ai_failed}
      end)

      result = SalesforceSuggestions.generate_suggestions_from_meeting(meeting)

      assert {:error, :ai_failed} = result
    end
  end

  describe "get_contact_field/2 helper" do
    test "maps Salesforce Company field to :company atom" do
      contact = %{
        id: "123",
        company: "Acme Corp"
      }

      # Access the private function via apply
      result = apply(SalesforceSuggestions, :get_contact_field, [contact, "Company"])

      assert result == "Acme Corp"
    end

    test "maps regular fields to lowercase atoms" do
      contact = %{
        id: "123",
        firstname: "John",
        email: "john@example.com"
      }

      result_firstname = apply(SalesforceSuggestions, :get_contact_field, [contact, "FirstName"])
      result_email = apply(SalesforceSuggestions, :get_contact_field, [contact, "Email"])

      assert result_firstname == "John"
      assert result_email == "john@example.com"
    end

    test "returns nil for missing fields" do
      contact = %{id: "123", firstname: "John"}

      result = apply(SalesforceSuggestions, :get_contact_field, [contact, "NonExistentField"])

      assert result == nil
    end
  end
end
