defmodule ServerSentEvent.ClientTest.AutoConnect do
  @behaviour ServerSentEvent.Client

  def start_link(port, pid \\ self()) do
    ServerSentEvent.Client.start_link(__MODULE__, %{port: port, pid: pid})
  end

  @impl ServerSentEvent.Client
  def init(state) do
    {:connect, request(state), state}
  end

  @impl ServerSentEvent.Client
  def handle_connect(response, state) do
    send(state.pid, {:connect, response})
    {:noreply, state}
  end

  @impl ServerSentEvent.Client
  def handle_connect_failure(reason, state) do
    send(state.pid, {:failure, reason})
    {:connect, request(state), state}
  end

  @impl ServerSentEvent.Client
  def handle_disconnect({:ok, :closed}, state) do
    send(state.pid, {:disconnect, {:ok, :closed}})
    {:connect, request(state), state}
  end

  @impl ServerSentEvent.Client
  def handle_event(event, state) do
    send(state.pid, event)
    state
  end

  @impl ServerSentEvent.Client
  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  defp request(state) do
    Raxx.request(:GET, "http://localhost:#{state.port}/events")
    |> Raxx.set_header("accept", "text/event-stream")
  end
end
