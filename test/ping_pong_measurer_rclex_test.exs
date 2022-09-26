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

  test "ping pong 2" do
    context = Rclex.rclexinit()
    node_counts = 1

    start_supervised!(Supervisor.child_spec({Ping2, {context, node_counts}}, id: Ping))

    start_supervised!(Supervisor.child_spec({Pong2, {context, node_counts}}, id: Pong))

    Ping2.publish()

    Process.sleep(100)
  end
end
