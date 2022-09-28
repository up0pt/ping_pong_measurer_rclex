defmodule PingPongMeasurerRclexTest do
  use ExUnit.Case

  @moduletag capture_log: true

  alias PingPongMeasurerRclex.Ping
  alias PingPongMeasurerRclex.Pong
  alias PingPongMeasurerRclex.Utils

  alias PingPongMeasurerRclex.Ping2
  alias PingPongMeasurerRclex.Pong2

  @tag :do_not_test
  test "ping pong" do
    context = Rclex.rclexinit()
    node_count = 1

    for index <- 1..node_count do
      start_supervised!(
        Supervisor.child_spec({Ping, {context, index}}, id: Utils.get_process_name(Ping, index))
      )

      start_supervised!(
        Supervisor.child_spec({Pong, {context, index}}, id: Utils.get_process_name(Pong, index))
      )
    end

    for index <- 1..node_count do
      assert :ok = Ping.publish(index)
    end

    Process.sleep(1000)
  end

  @tag :do_not_test
  @tag :tmp_dir
  test "ping pong 2", %{tmp_dir: tmp_dir_path} do
    context = Rclex.rclexinit()
    node_counts = 1
    payload_bytes = 10

    start_supervised!(
      Supervisor.child_spec({Ping2, {context, node_counts, tmp_dir_path}}, id: Ping)
    )

    start_supervised!(Supervisor.child_spec({Pong2, {context, node_counts}}, id: Pong))

    Ping2.get_publishers()
    |> Ping2.publish(String.duplicate("a", payload_bytes))

    Process.sleep(100)
  end

  @tag :tmp_dir
  test "start/stop ping processes", %{tmp_dir: tmp_dir_path} do
    context = Rclex.rclexinit()
    node_counts = 1
    payload_bytes = 1

    PingPongMeasurerRclex.start_os_info_measurement(tmp_dir_path)
    PingPongMeasurerRclex.start_ping_processes(context, node_counts, tmp_dir_path)
    PingPongMeasurerRclex.start_pong_processes(context, node_counts)
    PingPongMeasurerRclex.start_ping_measurer(tmp_dir_path)

    PingPongMeasurerRclex.start_ping_pong(String.duplicate("a", payload_bytes))
    PingPongMeasurerRclex.wait_until_all_nodes_finished(node_counts)

    PingPongMeasurerRclex.stop_ping_measurer()
    PingPongMeasurerRclex.stop_ping_processes()
    PingPongMeasurerRclex.stop_pong_processes()
    Process.sleep(100)
    PingPongMeasurerRclex.stop_os_info_measurement()
  end
end
