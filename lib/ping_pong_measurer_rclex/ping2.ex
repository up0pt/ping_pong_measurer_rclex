defmodule PingPongMeasurerRclex.Ping2 do
  use GenServer

  require Logger

  alias PingPongMeasurerRclex.Utils
  alias PingPongMeasurerRclex.Ping2.Measurer

  defmodule State do
    defstruct context: nil,
              node_id_list: [],
              publishers: [],
              subscribers: [],
              message_type: '',
              data_directory_path: "",
              from: nil
  end

  def start_link(args_tuple) do
    GenServer.start_link(__MODULE__, args_tuple, name: __MODULE__)
  end

  def init({context, node_counts, data_directory_path}) when is_integer(node_counts) do
    {:ok, node_id_list} = Rclex.ResourceServer.create_nodes(context, 'ping_node', node_counts)

    message_type = 'StdMsgs.Msg.String'
    ping_topic = 'ping_topic'
    pong_topic = 'pong_topic'

    {:ok, publishers} =
      Rclex.Node.create_publishers(node_id_list, message_type, ping_topic, :multi)

    {:ok, subscribers} =
      Rclex.Node.create_subscribers(node_id_list, message_type, pong_topic, :multi)

    {:ok,
     %State{
       context: context,
       node_id_list: node_id_list,
       publishers: publishers,
       subscribers: subscribers,
       message_type: message_type,
       data_directory_path: data_directory_path
     }}
  end

  def publish(payload) when is_binary(payload) do
    GenServer.cast(__MODULE__, {:publish, payload})
  end

  def start_subscribing(from \\ self()) when is_pid(from) do
    GenServer.cast(__MODULE__, {:start_subscribing, from})
  end

  def handle_cast({:publish, payload}, %State{} = state) when is_binary(payload) do
    for publisher <- state.publishers do
      {node_id, _topic, :pub} = publisher

      Measurer.start_measurement(node_id)

      ping(node_id, publisher, String.to_charlist(payload))
    end

    {:noreply, state}
  end

  def handle_cast({:start_subscribing, from}, %State{} = state) do
    for {node_id, index} <- Enum.with_index(state.node_id_list) do
      Measurer.start_link(%{node_id: node_id, data_directory_path: state.data_directory_path})

      publisher = Enum.at(state.publishers, index)
      subscriber = Enum.at(state.subscribers, index)

      Rclex.Subscriber.start_subscribing(subscriber, state.context, fn message ->
        message = Rclex.Msg.read(message, state.message_type)
        Logger.info('pong: ' ++ message.data)

        case Measurer.get_ping_counts(node_id) do
          0 ->
            # NOTE: 初回は外部から実行されインクリメントされるので、ここには来ない
            #       ここに来る場合は同一ネットワーク内に Pong が複数起動していないか確認すること
            raise RuntimeError

          100 ->
            Measurer.stop_measurement(node_id)
            Logger.debug("#{inspect(Measurer.get_measurement_time(node_id))} msec")
            Measurer.reset_ping_counts(node_id)
            Process.send(from, :finished, _opts = [])

          _ ->
            ping(node_id, publisher, message.data)
        end
      end)
    end

    {:noreply, %State{state | from: from}}
  end

  def ping(node_id, publisher, payload_charlist) when is_list(payload_charlist) do
    Rclex.Publisher.publish([publisher], [Utils.create_payload(payload_charlist)])
    Measurer.increment_ping_counts(node_id)
  end
end
