defmodule SocialScribe.TokenRefresherApi do
  @callback refresh_token(refresh_token :: String.t()) :: {:ok, map()} | {:error, any()}

  def refresh_token(refresh_token), do: impl().refresh_token(refresh_token)

  defp impl,
    do: Application.get_env(:social_scribe, :token_refresher_api, SocialScribe.TokenRefresher)
end
