defmodule PingPongMeasurerRclex.Ping2.Measurer do
  use GenServer

  defmodule State do
    defstruct ping_counts: 0, measurements: []
  end

  defmodule Measurement do
    defstruct measurement_time: nil, send_time: nil, recv_time: nil

    @type t() :: %__MODULE__{
            measurement_time: DateTime.t(),
            send_time: integer(),
            recv_time: integer()
          }
  end

  def start_link(%{args_tuple: args_tuple, name: name}) do
    GenServer.start_link(__MODULE__, args_tuple, name: to_global(name))
  end

  def get_ping_counts(name) do
    GenServer.call(to_global(name), :get_ping_counts)
  end

  def increment_ping_counts(name) do
    GenServer.cast(to_global(name), :increment_ping_counts)
  end

  def reset_ping_counts(name) do
    GenServer.cast(to_global(name), :reset_ping_counts)
  end

  def start_measurement(name) do
    GenServer.cast(to_global(name), :start_measurement)
  end

  def stop_measurement(name) do
    GenServer.cast(to_global(name), :stop_measurement)
  end

  def get_measurement_time(name) do
    GenServer.call(to_global(name), :get_measurement_time)
  end

  def init(_args_tuple) do
    {:ok, %State{ping_counts: 0}}
  end

  def handle_call(:get_ping_counts, _from, %State{} = state) do
    {:reply, state.ping_counts, state}
  end

  def handle_call(:get_measurement_time, _from, %State{measurements: [h | _t]} = state) do
    h = %Measurement{h | recv_time: System.monotonic_time(:microsecond)}
    {:reply, (h.recv_time - h.send_time) / 1000, state}
  end

  def handle_cast(:increment_ping_counts, %State{ping_counts: ping_counts} = state) do
    {:noreply, %State{state | ping_counts: ping_counts + 1}}
  end

  def handle_cast(:reset_ping_counts, %State{} = state) do
    {:noreply, %State{state | ping_counts: 0}}
  end

  def handle_cast(:start_measurement, %State{measurements: measurements} = state) do
    measurement = %Measurement{
      measurement_time: DateTime.utc_now(),
      send_time: System.monotonic_time(:microsecond)
    }

    {:noreply, %State{state | measurements: [measurement | measurements]}}
  end

  def handle_cast(:stop_measurement, %State{measurements: [h | t]} = state) do
    h = %Measurement{h | recv_time: System.monotonic_time(:microsecond)}
    {:noreply, %State{state | measurements: [h | t]}}
  end

  defp to_global(node_id_charlist) when is_list(node_id_charlist) do
    {:global, node_id_charlist ++ '_measurer'}
  end
end
