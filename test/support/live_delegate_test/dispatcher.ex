defmodule LiveDelegate.TestSupport.Dispatcher do
  use Phoenix.LiveView
  use LiveDelegate

  alias LiveDelegate.TestSupport.Recipient

  delegate(:recipient, Recipient, info: [:source])

  @impl Phoenix.LiveView
  def handle_event("local", payload, socket) do
    {:local_event, payload, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:local, payload}, socket) do
    {:local_info, payload, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div />
    """
  end
end
