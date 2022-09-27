defmodule PingPongMeasurerRclex.Pong2 do
  use GenServer

  require Logger

  alias PingPongMeasurerRclex.Utils

  def start_link(args_tuple) do
    GenServer.start_link(__MODULE__, args_tuple, name: __MODULE__)
  end

  def init({context, node_counts}) when is_integer(node_counts) do
    {:ok, node_id_list} = Rclex.ResourceServer.create_nodes(context, 'pong_node', node_counts)

    message_type = 'StdMsgs.Msg.String'
    ping_topic = 'ping_topic'
    pong_topic = 'pong_topic'

    {:ok, subscribers} =
      Rclex.Node.create_subscribers(node_id_list, message_type, ping_topic, :multi)

    {:ok, publishers} =
      Rclex.Node.create_publishers(node_id_list, message_type, pong_topic, :multi)

    for {_node_id, index} <- Enum.with_index(node_id_list) do
      subscriber = Enum.at(subscribers, index)
      publisher = Enum.at(publishers, index)

      Rclex.Subscriber.start_subscribing([subscriber], context, fn message ->
        message = Rclex.Msg.read(message, message_type)
        Logger.debug('ping: ' ++ message.data)

        Rclex.Publisher.publish([publisher], [Utils.create_payload(message.data)])
      end)
    end

    {:ok, nil}
  end
end
