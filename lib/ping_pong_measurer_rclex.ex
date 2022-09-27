defmodule PingPongMeasurerRclex do
  @moduledoc """
  Documentation for `PingPongMeasurerRclex`.
  """

  alias PingPongMeasurerRclex.Ping2, as: Ping
  alias PingPongMeasurerRclex.Pong2, as: Pong

  alias PingPongMeasurerRclex.OsInfo.CpuMeasurer
  alias PingPongMeasurerRclex.OsInfo.MemoryMeasurer

  def start_ping_processes(context, node_counts, data_directory_path) do
    Ping.start_link({context, node_counts, data_directory_path})
    Ping.start_subscribing()
  end

  def stop_ping_processes() do
    GenServer.stop(Ping)
  end

  def start_pong_processes(context, node_counts) do
    Pong.start_link({context, node_counts})
  end

  def stop_pong_processes() do
    GenServer.stop(Pong)
  end

  def start_ping_pong(payload) do
    Ping.publish(payload)
  end

  def wait_until_all_nodes_finished(node_counts, finished_node_counts \\ 0) do
    receive do
      :finished ->
        finished_node_counts = finished_node_counts + 1

        if(node_counts > finished_node_counts) do
          wait_until_all_nodes_finished(node_counts, finished_node_counts)
        end
    end
  end

  def start_os_info_measurement(data_directory_path, measurement_cycle_ms \\ 100)
      when is_binary(data_directory_path) and is_integer(measurement_cycle_ms) do
    ds_name = os_info_supervisor_name()
    PingPongMeasurerRclex.DynamicSupervisor.start_link(ds_name)

    DynamicSupervisor.start_child(
      ds_name,
      {CpuMeasurer, {data_directory_path, measurement_cycle_ms}}
    )

    DynamicSupervisor.start_child(
      ds_name,
      {MemoryMeasurer, {data_directory_path, measurement_cycle_ms}}
    )
  end

  def stop_os_info_measurement() do
    DynamicSupervisor.stop(os_info_supervisor_name())
  end

  defp os_info_supervisor_name() do
    Module.concat(__MODULE__, OsInfo.DynamicSupervisor)
  end
end
