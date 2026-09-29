defmodule LiveDelegate.TestSupport.MountDispatcher do
  use Phoenix.LiveView
  use LiveDelegate

  alias LiveDelegate.TestSupport.MountFirst
  alias LiveDelegate.TestSupport.MountSecond
  alias LiveDelegate.TestSupport.Recipient

  delegate(:first, MountFirst, events: false, info: false)
  delegate(:recipient, Recipient, info: false, mount: false)
  delegate(:second, MountSecond, events: false, info: false)

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
