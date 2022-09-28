defmodule PingPongMeasurerRclex.Ping2.Measurer do
  # NOTE: USE SHUTDOWN PARAMETER LIKE BELOW,
  #       WHEN YOUR CODES NEED SOME TIME TO PROCESS TERMINATE FUNCTION
  use GenServer, shutdown: :infinity

  require Logger

  @node_id_prefix 'ping_node'

  alias PingPongMeasurerRclex.Data

  defmodule State do
    defstruct ping_counts: 0, measurements: [], data_directory_path: "", process_index: 0
  end

  defmodule Measurement do
    defstruct measurement_time: nil, send_time: nil, recv_time: nil

    @type t() :: %__MODULE__{
            measurement_time: DateTime.t(),
            send_time: integer(),
            recv_time: integer()
          }
  end

  def start_link(%{node_id: node_id} = args_map) do
    GenServer.start_link(__MODULE__, args_map, name: to_global(node_id))
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

  def start_measurement(name, %DateTime{} = dt, monotonic_time) do
    GenServer.cast(to_global(name), {:start_measurement, dt, monotonic_time})
  end

  def stop_measurement(name, monotonic_time) do
    GenServer.cast(to_global(name), {:stop_measurement, monotonic_time})
  end

  def get_measurement_time(name) do
    GenServer.call(to_global(name), :get_measurement_time)
  end

  def init(%{node_id: node_id, data_directory_path: data_directory_path} = _args_map) do
    Process.flag(:trap_exit, true)

    @node_id_prefix ++ index = node_id

    {:ok,
     %State{
       ping_counts: 0,
       process_index: List.to_integer(index),
       data_directory_path: data_directory_path
     }}
  end

  def terminate(
        _reason,
        %State{
          measurements: measurements,
          data_directory_path: data_directory_path,
          process_index: process_index
        } = _state
      ) do
    # ex. if process_index == 99, do: "0099.csv"
    file_name = "#{String.pad_leading("#{process_index}", 4, "0")}.csv"
    file_path = Path.join(data_directory_path, file_name)

    Data.save(file_path, [header() | body(measurements)])
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

  def handle_cast(
        {:start_measurement, %DateTime{} = dt, monotonic_time},
        %State{measurements: measurements} = state
      ) do
    measurement = %Measurement{
      measurement_time: dt,
      send_time: monotonic_time
    }

    {:noreply, %State{state | measurements: [measurement | measurements]}}
  end

  def handle_cast({:stop_measurement, monotonic_time}, %State{measurements: [h | t]} = state) do
    h = %Measurement{h | recv_time: monotonic_time}
    {:noreply, %State{state | measurements: [h | t]}}
  end

  defp to_global(node_id_charlist) when is_list(node_id_charlist) do
    {:global, node_id_charlist ++ '_measurer'}
  end

  defp header() do
    [
      "measurement_time(utc)",
      "send time[microsecond]",
      "recv time[microsecond]",
      "took time[ms]"
    ]
  end

  @spec body([Measurement.t()]) :: list()
  defp body(measurements) when is_list(measurements) do
    Enum.reduce(measurements, [], fn %Measurement{} = measurement, rows ->
      row = [
        measurement.measurement_time,
        measurement.send_time,
        measurement.recv_time,
        took_time_ms(measurement)
      ]

      [row | rows]
    end)
  end

  defp took_time_ms(%Measurement{} = measurement) do
    (measurement.recv_time - measurement.send_time) / 1000
  end
end
