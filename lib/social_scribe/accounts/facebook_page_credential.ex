defmodule SocialScribe.Accounts.FacebookPageCredential do
  use Ecto.Schema
  import Ecto.Changeset

  schema "facebook_page_credentials" do
    field :category, :string
    field :facebook_page_id, :string
    field :page_name, :string
    field :page_access_token, :string
    field :selected, :boolean, default: false

    belongs_to :user, SocialScribe.Accounts.User
    belongs_to :user_credential, SocialScribe.Accounts.UserCredential

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(facebook_page_credential, attrs) do
    facebook_page_credential
    |> cast(attrs, [
      :facebook_page_id,
      :page_name,
      :page_access_token,
      :category,
      :user_id,
      :user_credential_id,
      :selected
    ])
    |> validate_required([
      :facebook_page_id,
      :page_name,
      :page_access_token,
      :user_id,
      :user_credential_id,
      :selected
    ])
    |> unique_constraint(:facebook_page_id)
    |> unique_constraint([:user_id, :selected])
  end
end
