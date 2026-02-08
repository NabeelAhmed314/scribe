defmodule SocialScribe.Poster do
  alias SocialScribe.LinkedInApi
  alias SocialScribe.FacebookApi
  alias SocialScribe.Accounts

  def post_on_social_media(platform, generated_content, current_user) do
    case platform do
      :linkedin -> post_on_linkedin(generated_content, current_user)
      :facebook -> post_on_facebook(generated_content, current_user)
      _ -> {:error, "Unsupported platform"}
    end
  end

  defp post_on_linkedin(generated_content, current_user) do
    case Accounts.get_user_linkedin_credential(current_user) do
      nil ->
        {:error, "LinkedIn credential not found"}

      user_credential ->
        LinkedInApi.post_text_share(
          user_credential.token,
          user_credential.uid,
          generated_content
        )
    end
  end

  defp post_on_facebook(generated_content, current_user) do
    case Accounts.get_user_selected_facebook_page_credential(current_user) do
      nil ->
        {:error, "Facebook page credential not found"}

      facebook_page_credential ->
        FacebookApi.post_message_to_page(
          facebook_page_credential.facebook_page_id,
          facebook_page_credential.page_access_token,
          generated_content
        )
    end
  end
end
