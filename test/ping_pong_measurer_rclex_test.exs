defmodule PingPongMeasurerRclexTest do
  use ExUnit.Case

  alias PingPongMeasurerRclex.Ping
  alias PingPongMeasurerRclex.Pong
  alias PingPongMeasurerRclex.Utils

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
end
