defmodule PingPongMeasurerRclex do
  @moduledoc """
  Documentation for `PingPongMeasurerRclex`.
  """

  alias PingPongMeasurerRclex.Ping2, as: Ping
  alias PingPongMeasurerRclex.Pong2, as: Pong

  def start_ping_processes(context, node_counts, data_directory_path) do
    Ping.start_link({context, node_counts, data_directory_path})
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
    Ping.start_subscribing()
    Ping.publish(payload)
  end

  def wait_until_all_node_finished(node_counts, finished_node_counts \\ 0) do
    receive do
      :finished ->
        finished_node_counts = finished_node_counts + 1

        if(node_counts > finished_node_counts) do
          wait_until_all_node_finished(node_counts, finished_node_counts)
        end
    end
  end
end
