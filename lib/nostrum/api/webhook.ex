defmodule Nostrum.Api.Webhook do
  alias Nostrum.Api
  alias Nostrum.Api.Helpers
  alias Nostrum.Constants
  alias Nostrum.Struct.Channel
  alias Nostrum.Struct.Webhook
  alias Nostrum.Struct.Guild.AuditLogEntry
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.Interaction
  alias Nostrum.Struct.User

  @doc """
  Creates a webhook.

  ## Parameters
    - `channel_id` - Id of the channel to send the message to.
    - `args` - Map with the following **required** keys:
      - `name` - Name of the webhook.
      - `avatar` - Base64 128x128 jpeg image for the default avatar.
    - `reason` - An optional reason for the guild audit log.
  """
  @spec create(
          Channel.id(),
          %{
            name: String.t(),
            avatar: String.t()
          },
          AuditLogEntry.reason()
        ) :: Api.error() | {:ok, Webhook.t()}
  def create(channel_id, args, reason \\ nil) do
    %{
      method: :post,
      route: Constants.webhooks_channel(channel_id),
      body: args,
      params: [],
      headers: Api.maybe_add_reason(reason)
    }
    |> Api.request()
    |> Helpers.handle_request_with_decode()
  end

  @doc """
  Deletes a webhook.

  ## Parameters
    - `webhook_id` - Id of webhook to delete.
    - `reason` - An optional reason for the guild audit log.
  """
  @spec delete(Webhook.id(), AuditLogEntry.reason()) :: Api.error() | {:ok}
  def delete(webhook_id, reason \\ nil) do
    Api.request(%{
      method: :delete,
      route: Constants.webhook(webhook_id),
      body: "",
      params: [],
      headers: Api.maybe_add_reason(reason)
    })
  end

  @doc """
  Edits a message previously created by the same webhook,
  args are the same as `execute/3`,
  however all fields are optional.
  """
  @doc since: "0.5.0"
  @spec edit_message(
          Webhook.id(),
          Webhook.token(),
          Message.id(),
          map()
        ) ::
          Api.error() | {:ok, Message.t()}
  def edit_message(webhook_id, webhook_token, message_id, args) do
    Api.request(
      :patch,
      Constants.webhook_message_edit(webhook_id, webhook_token, message_id),
      Api.combine_embeds(args) |> Api.combine_files()
    )
    |> Helpers.handle_request_with_decode({:struct, Message})
  end

  @doc """
  Executes a git webhook.

  ## Parameters
    - `webhook_id` - Id of the webhook to execute.
    - `webhook_token` - Token of the webhook to execute.
  """
  @spec execute_git(Webhook.id(), Webhook.token(), boolean) :: Api.error() | {:ok}
  def execute_git(webhook_id, webhook_token, wait \\ false) do
    Api.request(:post, Constants.webhook_git(webhook_id, webhook_token), wait: wait)
  end

  @doc """
  Executes a slack webhook.

  ## Parameters
    - `webhook_id` - Id of the webhook to execute.
    - `webhook_token` - Token of the webhook to execute.
  """
  @spec execute_slack(Webhook.id(), Webhook.token(), boolean) :: Api.error() | {:ok}
  def execute_slack(webhook_id, webhook_token, wait \\ false) do
    Api.request(:post, Constants.webhook_slack(webhook_id, webhook_token), wait: wait)
  end

  @doc """
  Executes a webhook.

  ## Parameters
  - `webhook_id` - Id of the webhook to execute.
  - `webhook_token` - Token of the webhook to execute.
  - `args` - Map with the following allowed keys:
    - `content` - Message content.
    - `files` - List of Files to send.
    - `embeds` - List of embeds to send.
    - `username` - Overrides the default name of the webhook.
    - `avatar_url` - Overrides the default avatar of the webhook.
    - `tts` - Whether the message should be read over text to speech.
    - `flags` - Bitwise flags.
    - `thread_id` - Send a message to the specified thread within the webhook's channel.
    - `allowed_mentions` - Mentions to allow in the webhook message
  - `wait` - Whether to return an error or not. Defaults to `false`.

  **Note**: If `wait` is `true`, this method will return a `Message.t()` on success.

  At least one of `content`, `files` or `embeds` should be supplied in the `args` parameter.
  """
  @spec execute(
          Webhook.id() | User.id(),
          Webhook.token() | Interaction.token(),
          Api.matrix(),
          boolean
        ) ::
          Api.error() | {:ok} | {:ok, Message.t()}
  def execute(webhook_id, webhook_token, args, wait \\ false)

  def execute(webhook_id, webhook_token, args, wait) do
    {thread_id, args} = Map.pop(args, :thread_id)
    args = Api.prepare_allowed_mentions(args)

    params =
      if is_nil(thread_id),
        do: [wait: wait],
        else: [wait: wait, thread_id: thread_id]

    Api.request(
      :post,
      Constants.webhook_token(webhook_id, webhook_token),
      Api.combine_embeds(args) |> Api.combine_files(),
      params
    )
    |> Helpers.handle_request_with_decode({:struct, Message})
  end

  @doc """
  Gets a webhook by id.

  ## Parameters
    - `webhook_id` - Id of the webhook to get.
  """
  @spec get(Webhook.id()) :: Api.error() | {:ok, Webhook.t()}
  def get(webhook_id) do
    Api.request(:get, Constants.webhook(webhook_id))
    |> Helpers.handle_request_with_decode({:struct, Webhook})
  end

  @doc """
  Retrieves the original message of a webhook.
  """
  @doc since: "0.7.0"
  @spec get_message(Webhook.t(), Message.id()) ::
          Api.error() | {:ok, Message.t()}
  def get_message(webhook, message_id) do
    Api.request(:get, Constants.webhook_message(webhook.id, webhook.token, message_id))
    |> Helpers.handle_request_with_decode({:struct, Message})
  end

  @doc """
  Gets a webhook by id and token.

  This method is exactly like `get/1` but does not require
  authentication.

  ## Parameters
    - `webhook_id` - Id of the webhook to get.
    - `webhook_token` - Token of the webhook to get.
  """
  @spec get_with_token(Webhook.id(), Webhook.token()) ::
          Api.error() | {:ok, Webhook.t()}
  def get_with_token(webhook_id, webhook_token) do
    Api.request(:get, Constants.webhook_token(webhook_id, webhook_token))
    |> Helpers.handle_request_with_decode({:struct, Webhook})
  end

  @doc """
  Modifies a webhook.

  ## Parameters
    - `webhook_id` - Id of the webhook to modify.
    - `args` - Map with the following *optional* keys:
      - `name` - Name of the webhook.
      - `avatar` - Base64 128x128 jpeg image for the default avatar.
    - `reason` - An optional reason for the guild audit log.
  """
  @spec modify(
          Webhook.id(),
          %{
            name: String.t(),
            avatar: String.t()
          },
          AuditLogEntry.reason()
        ) :: Api.error() | {:ok, Webhook.t()}
  def modify(webhook_id, args, reason \\ nil) do
    %{
      method: :patch,
      route: Constants.webhook(webhook_id),
      body: args,
      params: [],
      headers: Api.maybe_add_reason(reason)
    }
    |> Api.request()
    |> Helpers.handle_request_with_decode({:struct, Webhook})
  end

  @doc """
  Modifies a webhook with a token.

  This method is exactly like `modify_webhook/1` but does not require
  authentication.

  ## Parameters
    - `webhook_id` - Id of the webhook to modify.
    - `webhook_token` - Token of the webhook to get.
    - `args` - Map with the following *optional* keys:
      - `name` - Name of the webhook.
      - `avatar` - Base64 128x128 jpeg image for the default avatar.
    - `reason` - An optional reason for the guild audit log.
  """
  @spec modify_with_token(
          Webhook.id(),
          Webhook.token(),
          %{
            name: String.t(),
            avatar: String.t()
          },
          AuditLogEntry.reason()
        ) :: Api.error() | {:ok, Webhook.t()}
  def modify_with_token(webhook_id, webhook_token, args, reason \\ nil) do
    %{
      method: :patch,
      route: Constants.webhook_token(webhook_id, webhook_token),
      body: args,
      params: [],
      headers: Api.maybe_add_reason(reason)
    }
    |> Api.request()
    |> Helpers.handle_request_with_decode()
  end
end