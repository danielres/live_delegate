defmodule LiveDelegate.TestSupport.Dispatcher do
  use Phoenix.LiveView
  use LiveDelegate

  alias LiveDelegate.TestSupport.Recipient

  delegate(:recipient, Recipient, info: [:source])

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div />
    """
  end
end
