defmodule SocialScribe.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SocialScribeWeb.Telemetry,
      SocialScribe.Repo,
      # DNSCluster disabled - not needed for Cloud Run single-instance deployment
      # {DNSCluster, query: Application.get_env(:social_scribe, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:social_scribe, Oban)},
      {Phoenix.PubSub, name: SocialScribe.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: SocialScribe.Finch},
      # Start a worker by calling: SocialScribe.Worker.start_link(arg)
      # {SocialScribe.Worker, arg},
      # Start to serve requests, typically the last entry
      SocialScribeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SocialScribe.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SocialScribeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
