defmodule LiveDelegate.TestSupport.DisabledMountDispatcher do
  use Phoenix.LiveView
  use LiveDelegate

  alias LiveDelegate.TestSupport.Recipient

  delegate(:recipient, Recipient, events: false, info: false, mount: false)

  def mount_delegates(socket, params, session) do
    socket |> delegate_mount(params, session)
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div />
    """
  end
end
