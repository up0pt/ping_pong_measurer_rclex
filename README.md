# PingPongMeasurerRclex

## Getting Started

1. git clone this repo

2. start pong node first

```elixir
$ source /opt/ros/foxy/setup.bash
$ iex -S mix
iex> PingPongMeasurerRclex.start_pong_processes(Rclex.rclexinit(), _node_counts = 10)
```

3. start ping node and start measure

```elixir
$ source /opt/ros/foxy/setup.bash
$ iex -S mix
iex> MeasurementHelper.start_measurement(_node_counts = 10, _payload_bytes = 10000, _measurement_times = 100)
```


Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ping_pong_measurer_rclex>.

