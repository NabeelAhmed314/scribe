defmodule SocialScribe.Repo do
  use Ecto.Repo,
    otp_app: :social_scribe,
    adapter: Ecto.Adapters.Postgres
end
