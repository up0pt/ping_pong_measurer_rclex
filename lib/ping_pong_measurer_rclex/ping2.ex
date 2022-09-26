defmodule PingPongMeasurerRclex.Ping2 do
  use GenServer

  require Logger

  alias PingPongMeasurerRclex.Utils
  alias PingPongMeasurerRclex.Ping2.Measurer

  defmodule State do
    defstruct node_id_list: [], publishers: [], payload: ""
  end

  def start_link(args_tuple) do
    GenServer.start_link(__MODULE__, args_tuple, name: __MODULE__)
  end

  def init({context, node_counts}) when is_integer(node_counts) do
    {:ok, node_id_list} = Rclex.ResourceServer.create_nodes(context, 'ping_node', node_counts)

    message_type = 'StdMsgs.Msg.String'
    ping_topic = 'ping_topic'
    pong_topic = 'pong_topic'

    payload = Utils.create_payload('test')

    {:ok, publishers} =
      Rclex.Node.create_publishers(node_id_list, message_type, ping_topic, :multi)

    {:ok, subscribers} =
      Rclex.Node.create_subscribers(node_id_list, message_type, pong_topic, :multi)

    for {node_id, index} <- Enum.with_index(node_id_list) do
      Measurer.start_link(%{args_tuple: nil, name: node_id})

      publisher = Enum.at(publishers, index)
      subscriber = Enum.at(subscribers, index)

      Rclex.Subscriber.start_subscribing(subscriber, context, fn message ->
        message = Rclex.Msg.read(message, message_type)
        Logger.info('pong: ' ++ message.data)

        case Measurer.get_ping_counts(node_id) do
          0 ->
            # NOTE: 初回は外部から実行されインクリメントされるので、ここには来ない
            raise RuntimeError

          100 ->
            Measurer.stop_measurement(node_id)
            Logger.debug("#{inspect(Measurer.get_measurement_time(node_id))} msec")
            Measurer.reset_ping_counts(node_id)

          _ ->
            ping(node_id, publisher, payload)
        end
      end)
    end

    {:ok, %State{node_id_list: node_id_list, publishers: publishers, payload: payload}}
  end

  def publish() do
    GenServer.cast(__MODULE__, :publish)
  end

  def handle_cast(:publish, state) do
    for publisher <- state.publishers do
      {node_id, _topic, :pub} = publisher

      Measurer.start_measurement(node_id)
      ping(node_id, publisher, state.payload)
    end

    {:noreply, state}
  end

  def ping(node_id, publisher, payload) do
    Rclex.Publisher.publish([publisher], [payload])
    Measurer.increment_ping_counts(node_id)
  end
end
