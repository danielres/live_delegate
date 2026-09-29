defmodule LiveDelegate.TestSupport.Recipient do
  use LiveDelegate

  def handle_event(event, payload, socket) do
    {:event, event, payload, socket}
  end

  def handle_info(payload, socket) do
    {:info, payload, socket}
  end
end
