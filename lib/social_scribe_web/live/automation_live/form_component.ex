defmodule SocialScribeWeb.AutomationLive.FormComponent do
  use SocialScribeWeb, :live_component

  alias SocialScribe.Automations

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage automation records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="automation-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:platform]}
          type="select"
          label="Platform"
          options={Ecto.Enum.values(Automations.Automation, :platform)}
        />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:example]} type="textarea" label="Example" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Automation</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{automation: automation} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Automations.change_automation(automation))
     end)}
  end

  @impl true
  def handle_event("validate", %{"automation" => automation_params}, socket) do
    changeset =
      Automations.change_automation(
        socket.assigns.automation,
        Map.put(automation_params, "user_id", socket.assigns.current_user.id)
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"automation" => automation_params}, socket) do
    save_automation(socket, socket.assigns.action, automation_params)
  end

  defp save_automation(socket, :edit, automation_params) do
    params = Map.put(automation_params, "user_id", socket.assigns.current_user.id)

    case Automations.update_automation(socket.assigns.automation, params) do
      {:ok, automation} ->
        notify_parent({:saved, automation})

        {:noreply,
         socket
         |> put_flash(:info, "Automation updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_automation(socket, :new, automation_params) do
    params = Map.put(automation_params, "user_id", socket.assigns.current_user.id)

    case Automations.create_automation(params) do
      {:ok, automation} ->
        notify_parent({:saved, automation})

        {:noreply,
         socket
         |> put_flash(:info, "Automation created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
