defmodule GameSupervisor do

  @moduledoc """
  Este módulo permite crear partidas de forma dinámica durante la ejecución.
  Cada partida es un proceso GenServer (GameServer) supervisado independientemente.
  """

  use DynamicSupervisor

  ## INICIALIZACION DEL SUPERVISOR.

  def start_link(_opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

    # API para gestión de partidas.

  def crear_partida(tema, num_preguntas, tiempo) do
    id = System.unique_integer([:positive])
    opts = [id: id, tema: tema, num_preguntas: num_preguntas, tiempo: tiempo]

    spec = %{
      id: GameServer,
      start: {GameServer, :start_link, [opts]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, _pid} ->
        IO.puts("🎮 Partida creada con ID: #{id}")
        {:ok, id}

      {:error, error} ->
        {:error, error}
    end
  end

  def listar_partidas do
    Registry.select(:game_registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.map(fn id ->
      case GameServer.info(id) do
        {:ok, info} -> {id, info}
        info -> {id, info}
      end
    end)
  end
end
