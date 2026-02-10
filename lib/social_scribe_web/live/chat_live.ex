defmodule SocialScribeWeb.ChatLive do
  @moduledoc """
  LiveView for the CRM Chat Assistant interface.
  Allows users to search and tag contacts from HubSpot and Salesforce,
  then ask questions about them.
  """

  use SocialScribeWeb, :live_view

  import SocialScribeWeb.ModalComponents, only: [avatar: 1]
  import SocialScribeWeb.CoreComponents, only: [icon: 1]

  require Logger

  alias SocialScribe.Accounts
  alias SocialScribe.Chat
  alias SocialScribe.CrmQueryProcessor
  alias SocialScribe.HubspotApiBehaviour, as: HubspotApi
  alias SocialScribe.SalesforceApiBehaviour, as: SalesforceApi

  @impl true
  def mount(_params, _session, socket) do
    hubspot_credential = Accounts.get_user_hubspot_credential(socket.assigns.current_user.id)

    salesforce_credential =
      Accounts.get_user_salesforce_credential(socket.assigns.current_user.id)

    has_crm_connected = hubspot_credential != nil or salesforce_credential != nil

    # Load recent chat messages
    messages = Chat.list_recent_user_messages(socket.assigns.current_user.id, 50)

    socket =
      socket
      |> assign(:page_title, "CRM Chat Assistant")
      |> assign(:messages, messages)
      |> assign(:message_input, "")
      |> assign(:contact_search_query, "")
      |> assign(:contact_search_results, [])
      |> assign(:selected_contacts, [])
      |> assign(:searching_contacts, false)
      |> assign(:hubspot_searching, false)
      |> assign(:salesforce_searching, false)
      |> assign(:dropdown_open, false)
      |> assign(:mention_dropdown_open, false)
      |> assign(:mention_query, "")
      |> assign(:mention_search_results, [])
      |> assign(:hubspot_credential, hubspot_credential)
      |> assign(:salesforce_credential, salesforce_credential)
      |> assign(:has_crm_connected, has_crm_connected)
      |> assign(:processing, false)
      |> assign(:error, nil)
      |> assign(:current_tab, "chat")
      |> assign(:show_contact_search, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message_input, message)}
  end

  @impl true
  def handle_event("mention_selected", params, socket) do
    mention_text = params["mention_text"] || ""
    _display_name = params["display_name"] || ""
    contact_id = params["id"]
    source = params["source"]
    current_input = socket.assigns.message_input || ""

    # Replace the @mention query with the selected contact mention
    new_input =
      case String.last(current_input) do
        "@" ->
          current_input <> mention_text

        _ ->
          Regex.replace(~r/@[^\s]*$/, current_input, mention_text)
      end

    # Add the mentioned contact to selected_contacts if not already there
    already_selected =
      Enum.any?(socket.assigns.selected_contacts, fn c ->
        c.id == contact_id and c.source == source
      end)

    selected_contacts =
      if already_selected do
        socket.assigns.selected_contacts
      else
        # Find the full contact details from mention_search_results
        contact =
          Enum.find(socket.assigns.mention_search_results, fn c ->
            c.id == contact_id and c.source == source
          end)

        if contact do
          selected_contact = %{
            id: contact.id,
            firstname: contact.firstname,
            lastname: contact.lastname,
            email: contact.email,
            company: contact.company,
            source: contact.source,
            display_name: contact.display_name
          }

          socket.assigns.selected_contacts ++ [selected_contact]
        else
          socket.assigns.selected_contacts
        end
      end

    {:noreply,
     socket
     |> assign(:message_input, new_input)
     |> assign(:selected_contacts, selected_contacts)
     |> assign(:mention_dropdown_open, false)
     |> assign(:mention_query, "")
     |> assign(:mention_search_results, [])}
  end

  @impl true
  def handle_event("search_contacts", %{"value" => query}, socket) do
    query = String.trim(query)

    if String.length(query) >= 2 do
      # Determine which CRMs will be searched
      hubspot_will_search = socket.assigns.hubspot_credential != nil
      salesforce_will_search = socket.assigns.salesforce_credential != nil

      socket =
        socket
        |> assign(:hubspot_searching, hubspot_will_search)
        |> assign(:salesforce_searching, salesforce_will_search)
        |> assign(:searching_contacts, hubspot_will_search or salesforce_will_search)
        |> assign(:dropdown_open, true)
        |> assign(:contact_search_query, query)

      # Send async searches to both CRMs
      if hubspot_will_search do
        send(self(), {:search_hubspot, query, socket.assigns.hubspot_credential})
      end

      if salesforce_will_search do
        send(self(), {:search_salesforce, query, socket.assigns.salesforce_credential})
      end

      {:noreply, socket}
    else
      {:noreply,
       assign(socket,
         contact_search_query: query,
         contact_search_results: [],
         dropdown_open: query != ""
       )}
    end
  end

  @impl true
  def handle_event("select_contact", %{"id" => contact_id, "source" => source}, socket) do
    contact =
      Enum.find(socket.assigns.contact_search_results, fn c ->
        c.id == contact_id and c.source == source
      end)

    if contact do
      # Check for duplicates
      already_selected =
        Enum.any?(socket.assigns.selected_contacts, fn c ->
          c.id == contact.id and c.source == contact.source
        end)

      # Check max limit
      at_limit = length(socket.assigns.selected_contacts) >= 5

      cond do
        already_selected ->
          {:noreply, assign(socket, error: "Contact already tagged")}

        at_limit ->
          {:noreply,
           assign(socket,
             error: "Maximum 5 contacts can be tagged",
             dropdown_open: false,
             contact_search_query: "",
             contact_search_results: []
           )}

        true ->
          selected_contact = %{
            id: contact.id,
            firstname: contact.firstname,
            lastname: contact.lastname,
            email: contact.email,
            company: contact.company,
            source: contact.source,
            display_name: contact.display_name
          }

          {:noreply,
           assign(socket,
             selected_contacts: socket.assigns.selected_contacts ++ [selected_contact],
             dropdown_open: false,
             show_contact_search: false,
             contact_search_query: "",
             contact_search_results: [],
             error: nil
           )}
      end
    else
      {:noreply, assign(socket, error: "Contact not found")}
    end
  end

  @impl true
  def handle_event(
        "select_contact_for_context",
        %{
          "id" => contact_id,
          "source" => source,
          "firstname" => firstname,
          "display_name" => display_name
        },
        socket
      ) do
    contact =
      Enum.find(socket.assigns.contact_search_results, fn c ->
        c.id == contact_id and c.source == source
      end)

    if contact do
      # Check for duplicates
      already_selected =
        Enum.any?(socket.assigns.selected_contacts, fn c ->
          c.id == contact.id and c.source == contact.source
        end)

      # Check max limit
      at_limit = length(socket.assigns.selected_contacts) >= 5

      cond do
        already_selected ->
          {:noreply, assign(socket, error: "Contact already tagged", show_contact_search: false)}

        at_limit ->
          {:noreply,
           assign(socket,
             error: "Maximum 5 contacts can be tagged",
             show_contact_search: false,
             dropdown_open: false,
             contact_search_query: "",
             contact_search_results: []
           )}

        true ->
          selected_contact = %{
            id: contact.id,
            firstname: contact.firstname,
            lastname: contact.lastname,
            email: contact.email,
            company: contact.company,
            source: contact.source,
            display_name: contact.display_name
          }

          # Add mention to message input
          current_message = socket.assigns.message_input

          prefix =
            if current_message == "" or String.ends_with?(current_message, " "), do: "", else: " "

          new_message = current_message <> prefix <> "@" <> firstname <> " "

          socket =
            assign(socket,
              selected_contacts: socket.assigns.selected_contacts ++ [selected_contact],
              message_input: new_message,
              dropdown_open: false,
              show_contact_search: false,
              contact_search_query: "",
              contact_search_results: [],
              error: nil
            )

          # Push event to textarea to insert the mention visually
          {:noreply,
           push_event(socket, "insert_mention", %{
             firstname: firstname,
             display_name: display_name,
             id: contact.id,
             source: contact.source
           })}
      end
    else
      {:noreply, assign(socket, error: "Contact not found", show_contact_search: false)}
    end
  end

  @impl true
  def handle_event(
        "add_context_contact",
        params,
        socket
      ) do
    contact_id = params["id"]
    source = params["source"]
    firstname = params["firstname"]
    lastname = params["lastname"]
    email = params["email"]
    company = params["company"]
    display_name = params["display_name"]

    # Check for duplicates
    already_selected =
      Enum.any?(socket.assigns.selected_contacts, fn c ->
        c.id == contact_id and c.source == source
      end)

    # Check max limit
    at_limit = length(socket.assigns.selected_contacts) >= 5

    cond do
      already_selected ->
        {:noreply, assign(socket, error: "Contact already added", show_contact_search: false)}

      at_limit ->
        {:noreply,
         assign(socket,
           error: "Maximum 5 contacts can be added",
           show_contact_search: false,
           dropdown_open: false,
           contact_search_query: "",
           contact_search_results: []
         )}

      true ->
        selected_contact = %{
          id: contact_id,
          firstname: firstname,
          lastname: lastname,
          email: email,
          company: company,
          source: source,
          display_name: display_name
        }

        # Add mention to message input
        current_message = socket.assigns.message_input

        prefix =
          if current_message == "" or String.ends_with?(current_message, " "), do: "", else: " "

        new_message = current_message <> prefix <> "@" <> firstname <> " "

        updated_contacts = socket.assigns.selected_contacts ++ [selected_contact]

        socket =
          assign(socket,
            selected_contacts: updated_contacts,
            message_input: new_message,
            dropdown_open: false,
            show_contact_search: false,
            contact_search_query: "",
            contact_search_results: [],
            error: nil
          )

        # Push event to update textarea content with updated contacts for styling
        {:noreply,
         push_event(socket, "update_textarea", %{
           message: new_message,
           contacts: updated_contacts
         })}
    end
  end

  @impl true
  def handle_event(
        "select_mention",
        params,
        socket
      ) do
    contact_id = params["id"]
    source = params["source"]
    firstname = params["firstname"]
    lastname = params["lastname"]
    email = params["email"]
    company = params["company"]
    display_name = params["display_name"]

    # Check for duplicates
    already_selected =
      Enum.any?(socket.assigns.selected_contacts, fn c ->
        c.id == contact_id and c.source == source
      end)

    cond do
      already_selected ->
        {:noreply,
         assign(socket,
           mention_dropdown_open: false,
           mention_query: "",
           mention_search_results: []
         )}

      true ->
        selected_contact = %{
          id: contact_id,
          firstname: firstname,
          lastname: lastname,
          email: email,
          company: company,
          source: source,
          display_name: display_name
        }

        # Add mention to message input - replace the @query with @firstname
        current_message = socket.assigns.message_input
        mention_query = socket.assigns.mention_query

        # Robust replacement logic:
        # 1. Try to find the specific mention query (last occurrence) to handle edits in middle
        # 2. Fallback to replacing the last mention-like pattern if query is empty/stale

        new_message =
          cond do
            # Case 1: We have a specific query to target
            mention_query != "" ->
              # Find the last occurrence of @query to replace
              # We use a regex with negative lookahead to ensure we find the LAST instance
              pattern = ~r/@#{Regex.escape(mention_query)}(?!.*@#{Regex.escape(mention_query)})/

              if Regex.match?(pattern, current_message) do
                # Replace only the matched part
                Regex.replace(pattern, current_message, "@" <> firstname <> " ", global: false)
              else
                # Query not found (maybe text changed), try generic fallback
                replace_last_mention(current_message, firstname)
              end

            # Case 2: No query, just replace the last mention-like pattern
            true ->
              replace_last_mention(current_message, firstname)
          end

        updated_contacts = socket.assigns.selected_contacts ++ [selected_contact]

        socket =
          assign(socket,
            selected_contacts: updated_contacts,
            message_input: new_message,
            mention_dropdown_open: false,
            mention_query: "",
            mention_search_results: []
          )

        # Push event to update textarea content with updated contacts for styling
        {:noreply,
         push_event(socket, "update_textarea", %{
           message: new_message,
           contacts: updated_contacts
         })}
    end
  end

  @impl true
  def handle_event("remove_contact", %{"id" => contact_id, "source" => source}, socket) do
    updated_contacts =
      Enum.reject(socket.assigns.selected_contacts, fn c ->
        c.id == contact_id and c.source == source
      end)

    {:noreply, assign(socket, selected_contacts: updated_contacts, error: nil)}
  end

  @impl true
  def handle_event("toggle_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: !socket.assigns.dropdown_open)}
  end

  @impl true
  def handle_event("close_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: false)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, current_tab: tab)}
  end

  @impl true
  def handle_event("new_chat", _params, socket) do
    {:noreply,
     socket
     |> assign(:messages, [])
     |> assign(:message_input, "")
     |> assign(:selected_contacts, [])
     |> assign(:current_tab, "chat")
     |> push_event("update_textarea", %{message: "", contacts: []})}
  end

  @impl true
  def handle_event("open_contact_search", _params, socket) do
    {:noreply, assign(socket, show_contact_search: true, dropdown_open: true)}
  end

  @impl true
  def handle_event("close_contact_search", _params, socket) do
    {:noreply,
     assign(socket,
       show_contact_search: false,
       contact_search_query: "",
       contact_search_results: []
     )}
  end

  @impl true
  def handle_event("load_conversation", %{"message-id" => _message_id}, socket) do
    # Switch to chat tab and could load full conversation thread
    {:noreply, assign(socket, current_tab: "chat")}
  end

  @impl true
  def handle_event("sync_mentions", %{"message" => message, "mentions" => mention_names}, socket) do
    # Create a set of mention names (lowercase for case-insensitive comparison)
    current_mentions =
      mention_names
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()

    # Filter selected_contacts to only include those whose firstname or display_name is still in textarea
    updated_contacts =
      Enum.filter(socket.assigns.selected_contacts, fn contact ->
        firstname = contact[:firstname] || contact["firstname"] || ""
        display_name = contact[:display_name] || contact["display_name"] || ""

        MapSet.member?(current_mentions, String.downcase(firstname)) or
          MapSet.member?(current_mentions, String.downcase(display_name))
      end)

    # Preserve the message with @ symbols for validation
    {:noreply, assign(socket, message_input: message, selected_contacts: updated_contacts)}
  end

  @impl true
  def handle_event("mention_search", %{"query" => query}, socket) do
    query = String.trim(query)

    if String.length(query) >= 1 do
      socket =
        socket
        |> assign(:mention_query, query)
        |> assign(:mention_dropdown_open, true)
        |> assign(:hubspot_searching, socket.assigns.hubspot_credential != nil)
        |> assign(:salesforce_searching, socket.assigns.salesforce_credential != nil)

      # Send async searches to both CRMs
      if socket.assigns.hubspot_credential do
        send(self(), {:mention_search_hubspot, query, socket.assigns.hubspot_credential})
      end

      if socket.assigns.salesforce_credential do
        send(self(), {:mention_search_salesforce, query, socket.assigns.salesforce_credential})
      end

      {:noreply, socket}
    else
      {:noreply,
       assign(socket,
         mention_query: query,
         mention_search_results: [],
         mention_dropdown_open: query != ""
       )}
    end
  end

  @impl true
  def handle_event("clear_mention_search", _params, socket) do
    {:noreply,
     assign(socket,
       mention_dropdown_open: false,
       mention_query: "",
       mention_search_results: []
     )}
  end

  @impl true
  def handle_event(
        "add_mention_contact",
        %{"id" => contact_id, "source" => source, "message" => message} = params,
        socket
      ) do
    # Check if contact already exists in selected_contacts
    already_exists =
      Enum.any?(socket.assigns.selected_contacts, fn c ->
        c.id == contact_id and c.source == source
      end)

    if already_exists do
      {:noreply, assign(socket, :message_input, message)}
    else
      # Use passed contact data directly (from JavaScript event detail)
      selected_contact = %{
        id: contact_id,
        firstname: params["firstname"],
        lastname: params["lastname"],
        email: params["email"],
        company: params["company"],
        source: source,
        display_name: params["display_name"]
      }

      # Check max limit
      if length(socket.assigns.selected_contacts) >= 5 do
        {:noreply,
         socket
         |> assign(:message_input, message)
         |> put_flash(:warning, "Maximum 5 contacts can be tagged")}
      else
        {:noreply,
         assign(socket,
           selected_contacts: socket.assigns.selected_contacts ++ [selected_contact],
           message_input: message,
           mention_dropdown_open: false,
           mention_search_results: []
         )}
      end
    end
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    message = String.trim(socket.assigns.message_input)
    selected_contacts = socket.assigns.selected_contacts

    # Extract @mentions from message
    mentions = extract_mentions(message)

    # Check for unmatched mentions (check both display_name and firstname)
    unmatched_mentions =
      Enum.filter(mentions, fn mention ->
        not Enum.any?(selected_contacts, fn c ->
          display_name = c[:display_name] || c["display_name"] || ""
          firstname = c[:firstname] || c["firstname"] || ""

          String.downcase(display_name) == String.downcase(mention) or
            String.downcase(firstname) == String.downcase(mention)
        end)
      end)

    cond do
      message == "" ->
        {:noreply, put_flash(socket, :error, "Please enter a message")}

      Enum.empty?(selected_contacts) ->
        {:noreply, put_flash(socket, :error, "Please tag at least one contact")}

      not Enum.empty?(unmatched_mentions) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Unmatched mentions: #{Enum.join(unmatched_mentions, ", ")}. Please select these contacts or remove the mentions."
         )}

      true ->
        # Create user message in database
        contact_ids = extract_contact_ids(selected_contacts)
        contact_sources = build_contact_sources_map(selected_contacts)

        user_message_attrs = %{
          user_id: socket.assigns.current_user.id,
          content: message,
          type: "user",
          contact_ids: contact_ids,
          contact_sources: contact_sources,
          metadata: %{tagged_contacts: selected_contacts}
        }

        case Chat.create_message(user_message_attrs) do
          {:ok, user_message} ->
            # Add user message to UI immediately
            updated_messages = socket.assigns.messages ++ [user_message]

            # Send async message for AI processing
            send(self(), {:process_chat_message, message, selected_contacts})

            {:noreply,
             socket
             |> assign(:messages, updated_messages)
             |> assign(:message_input, "")
             |> assign(:selected_contacts, [])
             |> assign(:processing, true)
             |> clear_flash()
             |> push_event("update_textarea", %{message: "", contacts: []})}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to send message. Please try again.")}
        end
    end
  end

  defp extract_contact_ids(contacts) do
    Enum.map(contacts, fn c -> c.id end)
  end

  defp build_contact_sources_map(contacts) do
    contacts
    |> Enum.map(fn c -> {c.id, c.source} end)
    |> Enum.into(%{})
  end

  defp extract_mentions(message) do
    # Regex to find @mentions - matches @ followed by word characters and spaces
    regex = ~r/@([^@\n]+?)(?=\s|$|@)/u

    Regex.scan(regex, message)
    |> Enum.map(fn [_, mention] -> String.trim(mention) end)
    |> Enum.filter(fn mention -> String.length(mention) > 0 end)
  end

  @doc """
  Highlights @mentions in message content by wrapping them in styled spans.
  Returns HTML-safe content string with highlighted mentions.
  Handles both atom and string keys for contact data.
  """
  def highlight_mentions(content, selected_contacts) do
    # Build a regex pattern for all contact display names
    # Handle both atom and string keys
    patterns =
      selected_contacts
      |> Enum.map(fn c ->
        display_name = c[:display_name] || c["display_name"] || ""
        Regex.escape(display_name)
      end)
      |> Enum.filter(fn p -> p != "" end)
      |> Enum.join("|")

    if patterns == "" do
      Phoenix.HTML.html_escape(content)
    else
      # Replace @ContactName with highlighted version
      regex = ~r/@(#{patterns})/u

      parts =
        String.split(content, regex, include_captures: true)
        |> Enum.map(fn part ->
          if String.starts_with?(part, "@") do
            # Find the contact for this mention to get the source
            contact_name = String.slice(part, 1..-1//1)

            contact =
              Enum.find(selected_contacts, fn c ->
                (c[:display_name] || c["display_name"] || "") == contact_name
              end)

            source = contact[:source] || contact["source"] || "salesforce"

            source_class =
              if source == "hubspot" do
                "bg-orange-200 text-orange-800"
              else
                "bg-blue-200 text-blue-800"
              end

            escaped_part = Phoenix.HTML.html_escape(part)

            part_str =
              case escaped_part do
                {:safe, str} -> str
                str -> str
              end

            {:safe,
             "<span class=\"#{source_class} px-1.5 py-0.5 rounded font-medium\">#{part_str}</span>"}
          else
            Phoenix.HTML.html_escape(part)
          end
        end)

      # Concatenate all parts into a single safe string
      {:safe,
       parts
       |> Enum.map(fn
         {:safe, str} -> str
         str -> str
       end)
       |> Enum.join()}
    end
  end

  @impl true
  def handle_info({:search_hubspot, query, credential}, socket) do
    case HubspotApi.search_contacts(credential, query) do
      {:ok, contacts} ->
        hubspot_results =
          Enum.map(contacts, fn c ->
            Map.put(c, :source, "hubspot")
          end)

        send(self(), {:contact_search_results, hubspot_results, "hubspot"})

      {:error, _reason} ->
        send(self(), {:contact_search_results, [], "hubspot"})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:search_salesforce, query, credential}, socket) do
    case SalesforceApi.search_contacts(credential, query) do
      {:ok, contacts} ->
        salesforce_results =
          Enum.map(contacts, fn c ->
            Map.put(c, :source, "salesforce")
          end)

        send(self(), {:contact_search_results, salesforce_results, "salesforce"})

      {:error, _reason} ->
        send(self(), {:contact_search_results, [], "salesforce"})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:contact_search_results, results, source}, socket) do
    # Merge new results with existing ones
    current_results = socket.assigns.contact_search_results

    # Remove existing results from this source
    filtered_results = Enum.reject(current_results, fn c -> c.source == source end)

    # Add new results
    merged_results = filtered_results ++ results

    # Update the searching flag for the specific source
    socket =
      case source do
        "hubspot" -> assign(socket, :hubspot_searching, false)
        "salesforce" -> assign(socket, :salesforce_searching, false)
        _ -> socket
      end

    # Compute overall searching state
    searching_contacts = socket.assigns.hubspot_searching or socket.assigns.salesforce_searching

    {:noreply,
     assign(socket,
       contact_search_results: merged_results,
       searching_contacts: searching_contacts
     )}
  end

  @impl true
  def handle_info({:mention_search_hubspot, query, credential}, socket) do
    case HubspotApi.search_contacts(credential, query) do
      {:ok, contacts} ->
        hubspot_results =
          Enum.map(contacts, fn c ->
            Map.put(c, :source, "hubspot")
          end)

        send(self(), {:mention_search_results, hubspot_results, "hubspot"})

      {:error, _reason} ->
        send(self(), {:mention_search_results, [], "hubspot"})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:mention_search_salesforce, query, credential}, socket) do
    case SalesforceApi.search_contacts(credential, query) do
      {:ok, contacts} ->
        salesforce_results =
          Enum.map(contacts, fn c ->
            Map.put(c, :source, "salesforce")
          end)

        send(self(), {:mention_search_results, salesforce_results, "salesforce"})

      {:error, _reason} ->
        send(self(), {:mention_search_results, [], "salesforce"})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:mention_search_results, results, source}, socket) do
    # Merge new results with existing ones
    current_results = socket.assigns.mention_search_results

    # Remove existing results from this source
    filtered_results = Enum.reject(current_results, fn c -> c.source == source end)

    # Filter out contacts that are already selected/tagged to prevent duplicate tagging
    # Check against selected_contacts by ID and Source
    new_results_filtered =
      Enum.reject(results, fn result ->
        Enum.any?(socket.assigns.selected_contacts, fn selected ->
          selected.id == result.id and selected.source == result.source
        end)
      end)

    # Add new results
    merged_results = filtered_results ++ new_results_filtered

    # Update the searching flag for the specific source
    socket =
      case source do
        "hubspot" -> assign(socket, :hubspot_searching, false)
        "salesforce" -> assign(socket, :salesforce_searching, false)
        _ -> socket
      end

    {:noreply,
     assign(socket,
       mention_search_results: merged_results
     )}
  end

  @impl true
  def handle_info({:process_chat_message, message, contacts}, socket) do
    try do
      # Fetch recent conversation history for context
      conversation_history = Chat.list_recent_user_messages(socket.assigns.current_user.id, 10)

      # Process the query with CRM data, conversation history, and AI
      case CrmQueryProcessor.process_query(
             socket.assigns.current_user,
             message,
             contacts,
             conversation_history
           ) do
        {:ok, ai_response} ->
          send(self(), {:ai_response_ready, {:ok, ai_response}})

        {:error, reason} ->
          send(self(), {:ai_response_ready, {:error, reason}})
      end
    rescue
      _error ->
        send(self(), {:ai_response_ready, {:error, :processing_failed}})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:ai_response_ready, {:ok, response}}, socket) do
    # Get the last user message to copy its tagged_contacts
    last_user_message =
      socket.assigns.messages
      |> Enum.reverse()
      |> Enum.find(fn m -> m.type == "user" end)

    tagged_contacts =
      case last_user_message do
        nil -> []
        msg -> msg.metadata["tagged_contacts"] || []
      end

    # Create assistant message in database with tagged_contacts
    assistant_message_attrs = %{
      user_id: socket.assigns.current_user.id,
      content: response,
      type: "assistant",
      metadata: %{tagged_contacts: tagged_contacts}
    }

    case Chat.create_message(assistant_message_attrs) do
      {:ok, _assistant_message} ->
        # Reload messages from database to ensure proper ordering
        messages = Chat.list_recent_user_messages(socket.assigns.current_user.id, 50)

        {:noreply,
         socket
         |> assign(:messages, messages)
         |> assign(:processing, false)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Failed to save AI response")}
    end
  end

  @impl true
  def handle_info({:ai_response_ready, {:error, reason}}, socket) do
    error_message =
      case reason do
        :no_contact_data_available ->
          "Unable to retrieve contact information. Please check your CRM connections."

        :ai_generation_failed ->
          "AI response generation failed. Please try again."

        _ ->
          Logger.error("Chat error: #{inspect(reason)}")
          "An error occurred while processing your question. Please try again."
      end

    # Create error message as assistant response
    assistant_message_attrs = %{
      user_id: socket.assigns.current_user.id,
      content: "I apologize, but #{error_message}",
      type: "assistant",
      metadata: %{error: true, error_reason: reason}
    }

    case Chat.create_message(assistant_message_attrs) do
      {:ok, assistant_message} ->
        messages = socket.assigns.messages ++ [assistant_message]

        {:noreply,
         socket
         |> assign(:messages, messages)
         |> assign(:processing, false)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, error_message)}
    end
  end

  @doc """
  Returns a list of unique source strings from selected contacts.
  """
  def get_unique_sources(contacts) when is_list(contacts) do
    contacts
    |> Enum.map(fn c ->
      cond do
        is_map(c) -> c[:source] || c["source"]
        true -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
  end

  def get_unique_sources(_), do: []

  @doc """
  Safely extracts tagged_contacts from message metadata, handling both atom and string keys.
  """
  def get_tagged_contacts(metadata) when is_map(metadata) do
    cond do
      is_list(metadata[:tagged_contacts]) -> metadata[:tagged_contacts]
      is_list(metadata["tagged_contacts"]) -> metadata["tagged_contacts"]
      true -> []
    end
  end

  def get_tagged_contacts(_), do: []

  @doc """
  Formats message content for display by removing @ prefix from mentions.
  Returns HTML-safe content.
  """
  def format_mentions_for_display(content, selected_contacts) do
    # Build a regex pattern for all contact display names AND firstnames
    patterns =
      selected_contacts
      |> Enum.flat_map(fn c ->
        display_name = c[:display_name] || c["display_name"] || ""
        firstname = c[:firstname] || c["firstname"] || ""
        [display_name, firstname]
      end)
      |> Enum.filter(fn p -> p != "" end)
      |> Enum.uniq()
      # Sort by length descending to match longer names first (e.g. "Prabhas Kumar" before "Prabhas")
      |> Enum.sort_by(&String.length/1, :desc)
      |> Enum.map(&Regex.escape/1)
      |> Enum.join("|")

    if patterns == "" do
      Phoenix.HTML.html_escape(content)
    else
      # Regex to match @ContactName where ContactName is one of our patterns
      # Capture group 1 contains just the name without the @
      regex = ~r/@(#{patterns})\b/u

      # Use Regex.replace with a callback function
      result =
        Regex.replace(regex, content, fn _full_match, contact_name ->
          # Find the contact that matches this name
          contact =
            Enum.find(selected_contacts, fn c ->
              name = c[:display_name] || c["display_name"] || ""
              firstname = c[:firstname] || c["firstname"] || ""
              name == contact_name || firstname == contact_name
            end)

          if contact do
            source = contact[:source] || contact["source"] || "salesforce"

            source_class =
              if source == "hubspot" do
                "bg-orange-100 text-orange-700 border-orange-200"
              else
                "bg-blue-100 text-blue-700 border-blue-200"
              end

            # Return the styled span (without the @ symbol)
            "<span class=\"#{source_class} px-2 py-0.5 rounded-full text-xs font-medium border inline-block mx-0.5\">#{contact_name}</span>"
          else
            # Fallback: return the original text if no contact found
            "@#{contact_name}"
          end
        end)

      # Return as HTML safe
      {:safe, result}
    end
  end

  defp replace_last_mention(message, firstname) do
    # Regex for finding the LAST mention-like pattern (@ followed by chars)
    # This pattern matches @..., optionally trailing spaces, and ensures no other @ follows
    regex = ~r/(@[^\s]*\s*)$/

    if Regex.match?(regex, message) do
      Regex.replace(regex, message, "@" <> firstname <> " ")
    else
      # If no match found, append (absolute fallback)
      message <> "@" <> firstname <> " "
    end
  end
end
