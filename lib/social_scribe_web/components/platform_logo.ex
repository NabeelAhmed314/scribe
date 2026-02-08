defmodule SocialScribeWeb.PlatformLogo do
  use SocialScribeWeb, :html

  attr :recall_bot, :map, required: true
  attr :class, :string, required: true

  def platform_logo(assigns) do
    platform =
      cond do
        String.contains?(assigns.recall_bot.meeting_url, "meet.google.com") -> "google_meet"
        String.contains?(assigns.recall_bot.meeting_url, "zoom.us") -> "zoom"
        true -> "google_meet"
      end

    assigns =
      assigns
      |> assign(assigns)
      |> assign(:platform, platform)

    ~H"""
    <%= case @platform do %>
      <% "google_meet" -> %>
        <.google_meet_logo class={@class} />
      <% "zoom" -> %>
        <.zoom_logo class={@class} />
      <% _ -> %>
        <.google_meet_logo class={@class} />
    <% end %>
    """
  end

  attr :class, :string, required: true

  defp google_meet_logo(assigns) do
    ~H"""
    <svg class={@class} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 87.5 72">
      <path fill="#00832d" d="M49.5 36l8.53 9.75 11.47 7.33 2-17.02-2-16.64-11.69 6.44z" />
      <path fill="#0066da" d="M0 51.5V66c0 3.315 2.685 6 6 6h14.5l3-10.96-3-9.54-9.95-3z" />
      <path fill="#e94235" d="M20.5 0L0 20.5l10.55 3 9.95-3 2.95-9.41z" />
      <path fill="#2684fc" d="M20.5 20.5H0v31h20.5z" />
      <path
        fill="#00ac47"
        d="M82.6 8.68L69.5 19.42v33.66l13.16 10.79c1.97 1.54 4.85.135 4.85-2.37V11c0-2.535-2.945-3.925-4.91-2.32zM49.5 36v15.5h-29V72h43c3.315 0 6-2.685 6-6V53.08z"
      />
      <path fill="#ffba00" d="M63.5 0h-43v20.5h29V36l20-16.57V6c0-3.315-2.685-6-6-6z" />
    </svg>
    """
  end

  attr :class, :string, required: true

  defp zoom_logo(assigns) do
    ~H"""
    <svg class={@class} xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" fill="#000000">
      <g stroke-width="0"></g>
      <g stroke-linecap="round" stroke-linejoin="round"></g>
      <g>
        <rect width="512" height="512" rx="15%" fill="#2D8CFF"></rect>
        <path
          fill="#ffffff"
          d="M428 357c8 2 15-2 19-8 2-3 2-8 2-19V179c0-11 0-15-2-19-3-8-11-11-19-8-21 14-67 55-68 72-.8 3-.8 8-.8 15v38c0 8 0 11 .8 15 1 8 4 15 8 19 12 9 52 45 61 45zM64 187c0-15 0-23 3-27 2-4 8-8 11-11 4-3 11-3 27-3h129c38 0 57 0 72 8 11 8 23 15 30 30 8 15 8 34 8 72v68c0 15 0 23-3 27-2 4-8 8-11 11-4 3-11 3-27 3H174c-38 0-57 0-72-8-11-8-23-15-30-30-8-15-8-34-8-72z"
        >
        </path>
      </g>
    </svg>
    """
  end
end
