defmodule GameServer do

  @moduledoc """
  Módulo que implementa un GenServer que gestiona partidas de trivia concurrentes
  y distribuidas. Permite que múltiples jugadores participen simultáneamente en una
  partida de preguntas y respuestas con temas específicos.
  """

  use GenServer
  alias QuestionBank
  alias UserManager

    # Estructura de estado de servidor.

  defstruct [
    :id,
    :tema,
    :num_preguntas,
    :tiempo,
    jugadores: [],
    puntajes: %{},
    preguntas: [],
    actual: 0,
    respuestas_actual: %{},
    estado: :esperando,
    procesos_escucha: %{}
  ]

    # Configuracion del servidor (Obtiene, configura y verifica el nodo principal).

  defp get_server_node do
    Application.get_env(:trivia, :server_node, Node.self())
  end

  def set_server_node(node) when is_atom(node) do
    Application.put_env(:trivia, :server_node, node)
  end

  defp es_servidor? do
    Node.self() == get_server_node()
  end

  ## INICIO DE SERVER.

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:id]))
  end

  defp via_tuple(id), do: {:via, Registry, {:game_registry, id}}

    # API con soporte distribuido.

  def unirse_a_partida(id, jugador) do
    if es_servidor?() do
      GenServer.call(via_tuple(id), {:agregar_jugador, jugador})
    else
      :rpc.call(get_server_node(), GenServer, :call, [via_tuple(id), {:agregar_jugador, jugador}])
    end
  end

    # PID que envia mensajes (Nueva pregunta, Respuesta recibida, Resultado de preguntas y Finalizacion de partida).

  def registrar_escucha(id, jugador, pid) do
    if es_servidor?() do
      GenServer.call(via_tuple(id), {:registrar_escucha, jugador, pid})
    else
      :rpc.call(get_server_node(), GenServer, :call, [via_tuple(id), {:registrar_escucha, jugador, pid}])
    end
  end

    # Inciar partida.

  def iniciar(id) do
    if es_servidor?() do
      GenServer.call(via_tuple(id), :iniciar)
    else
      :rpc.call(get_server_node(), GenServer, :call, [via_tuple(id), :iniciar])
    end
  end

    # Registra la respuesta de un jugador a la pregunta actual.

  def responder(id, jugador, respuesta) do
    if es_servidor?() do
      GenServer.call(via_tuple(id), {:responder, jugador, respuesta})
    else
      :rpc.call(get_server_node(), GenServer, :call, [via_tuple(id), {:responder, jugador, respuesta}])
    end
  end

    # Obtiene estado de la partida

  def info(id) do
    if es_servidor?() do
      GenServer.call(via_tuple(id), :info)
    else
      :rpc.call(get_server_node(), GenServer, :call, [via_tuple(id), :info])
    end
  end

  def partida_existe?(id) do
    server = get_server_node()

    if Node.self() == server do
      resultado = Registry.lookup(:game_registry, id)
      log_servidor("🔍 Verificando partida '#{id}' localmente: #{inspect(resultado)}")
      case resultado do
        [] -> false
        _ -> true
      end
    else
      resultado = :rpc.call(server, Registry, :lookup, [:game_registry, id])
      IO.puts("🔍 DEBUG: Buscando partida '#{id}' en servidor #{server}")
      IO.puts("   Resultado: #{inspect(resultado)}")

      case resultado do
        [] -> false
        [_|_] -> true
        {:badrpc, reason} ->
          IO.puts("❌ Error RPC al verificar partida: #{inspect(reason)}")
          false
      end
    end
  end

  def crear_partida_remota(id, tema, num_preguntas, tiempo) do
    server = get_server_node()

    :rpc.call(
      server,
      DynamicSupervisor,
      :start_child,
      [GameSupervisor, {GameServer, [id: id, tema: tema, num_preguntas: num_preguntas, tiempo: tiempo]}]
    )
  end

  ## CALLBACKS DE GENSERVER

    # Inicializa el GenServer creando el estado, cargando preguntas y dejando la partida lista en :esperando,
    # asumiendo que los datos ya fueron validados.

  def init(opts) do
    estado = %__MODULE__{
      id: opts[:id],
      tema: opts[:tema],
      num_preguntas: opts[:num_preguntas],
      tiempo: opts[:tiempo],
      preguntas: QuestionBank.obtener_aleatorias(opts[:tema], opts[:num_preguntas])
    }

    log_servidor("✅ Partida #{estado.id} creada (tema: #{estado.tema})")
    {:ok, estado}
  end

  def handle_call(:info, _from, estado), do: {:reply, estado, estado}

    # Verifica que el jugador esté en lista de jugadores antes de regitrar la PID.

  def handle_call({:registrar_escucha, jugador, pid}, _from, estado) do
    if Enum.member?(estado.jugadores, jugador) do
      nuevo_estado = %{estado | procesos_escucha: Map.put(estado.procesos_escucha, jugador, pid)}
      {:reply, {:ok, "Proceso registrado"}, nuevo_estado}
    else
      {:reply, {:error, "No estás en esta partida"}, estado}
    end
  end

    # Callback para unirse a una partida.

  def handle_call({:agregar_jugador, jugador}, _from, estado) do
    cond do
      estado.estado != :esperando ->
        {:reply, {:error, "La partida ya comenzó"}, estado}

      Enum.member?(estado.jugadores, jugador) ->
        {:reply, {:error, "El jugador ya está en la partida"}, estado}

      length(estado.jugadores) >= 4 ->
        {:reply, {:error, "La partida está llena (máx. 4 jugadores)"}, estado}

      true ->
        nuevo_estado = %{
          estado
          | jugadores: estado.jugadores ++ [jugador],
            puntajes: Map.put(estado.puntajes, jugador, 0)
        }

        log_servidor("👤 #{jugador} se unió a la partida #{estado.id}")
        {:reply, {:ok, "Jugador agregado"}, nuevo_estado}
    end
  end

    # Callback para inicar una partida.

  def handle_call(:iniciar, _from, estado) do
    cond do
      estado.estado == :en_juego ->
        {:reply, {:error, "La partida ya está en curso"}, estado}

      estado.jugadores == [] ->
        {:reply, {:error, "No hay jugadores en la partida"}, estado}

      true ->
        log_servidor("🚀 La partida #{estado.id} ha comenzado!")

        broadcast_a_jugadores(estado, {:partida_iniciada, "🚀 La partida ha comenzado. Prepárate para la primera pregunta."})

        send(self(), :siguiente_pregunta)
        nuevo_estado = %{estado | estado: :en_juego, actual: 0, respuestas_actual: %{}}
        {:reply, {:ok, "Partida iniciada"}, nuevo_estado}
    end
  end

    # Callback para registrar respuestas.

  def handle_call({:responder, jugador, resp}, _from, estado) do
    cond do
      estado.estado != :en_juego ->
        {:reply, {:error, "La partida no está en curso"}, estado}

      Map.has_key?(estado.respuestas_actual, jugador) ->
        {:reply, {:error, "Ya respondiste esta pregunta"}, estado}

      true ->
        nuevo_respuestas = Map.put(estado.respuestas_actual, jugador, resp)
        notificar_jugador(estado, jugador, {:respuesta_recibida, "✅ Respuesta recibida"})
        {:reply, {:ok, "Respuesta recibida"}, %{estado | respuestas_actual: nuevo_respuestas}}
    end
  end

    # Callback de manejo de preguntas.

  def handle_info(:siguiente_pregunta, estado) do
    pregunta = Enum.at(estado.preguntas, estado.actual)

    if pregunta == nil do
      # Fin de la partida.
      ranking =
        estado.puntajes
        |> Enum.sort_by(fn {_jug, puntos} -> -puntos end)

      ranking_text = Enum.map_join(ranking, "\n", fn {jug, puntos} ->
        "  #{jug}: #{puntos} puntos"
      end)

      log_servidor("🏁 Partida #{estado.id} finalizada. Ranking final:\n#{ranking_text}")

      Enum.each(ranking, fn {jug, puntos} ->
        UserManager.actualizar_puntaje(jug, puntos, estado.tema)
      end)

      broadcast_a_jugadores(estado, {:partida_finalizada, "🏁 Partida finalizada\n#{ranking_text}"})
      guardar_resultado(estado, ranking)
      ## FIN DEL SERVIDOR.
      {:noreply, %{estado | estado: :finalizado}}

    else
      pregunta_texto = """

      ❓ Pregunta #{estado.actual + 1}: #{pregunta.texto}
        a) #{Enum.at(pregunta.opciones, 0)}
        b) #{Enum.at(pregunta.opciones, 1)}
        c) #{Enum.at(pregunta.opciones, 2)}
        d) #{Enum.at(pregunta.opciones, 3)}

      ⏱️  Tiempo: #{estado.tiempo} segundos
      💡 Usa: answer #{estado.actual + 1} b
      """

      broadcast_a_jugadores(estado, {:nueva_pregunta, pregunta_texto})

      Process.send_after(self(), :fin_pregunta, estado.tiempo * 1000)
      {:noreply, %{estado | actual: estado.actual + 1, respuestas_actual: %{}}}
    end
  end

    # Callback para avaluar respuestas, asignar puntakes y enviar resultados.

  def handle_info(:fin_pregunta, estado) do
    pregunta = Enum.at(estado.preguntas, estado.actual - 1)

    nuevo_estado =
      Enum.reduce(estado.jugadores, estado, fn jug, acc ->
        resp = Map.get(acc.respuestas_actual, jug)

        indice_respuesta =
          case resp do
            "1" -> 1
            "2" -> 2
            "3" -> 3
            "4" -> 4
            "a" -> 1
            "b" -> 2
            "c" -> 3
            "d" -> 4
            _ -> 0
          end

        {puntos, mensaje} =
          cond do
            resp == nil ->
              {-5, "⏰ #{jug} no respondió. -5 puntos"}

            indice_respuesta == pregunta.correcta ->
              {10, "🎉 #{jug} respondió correctamente. +10 puntos"}

            true ->
              {-5, "❌ #{jug} respondió incorrectamente. -5 puntos"}
          end

        broadcast_a_jugadores(acc, {:resultado_pregunta, mensaje})

        %{acc | puntajes: Map.update!(acc.puntajes, jug, &(&1 + puntos))}
      end)

    Process.send_after(self(), :siguiente_pregunta, 1500)
    {:noreply, nuevo_estado}
  end

    # Funciones de Broadcast y Notificaciones (Envia mensajes a todos los jugadores registrados).

  defp broadcast_a_jugadores(estado, mensaje) do
    Enum.each(estado.procesos_escucha, fn {_jugador, pid} ->
      case mensaje do
        {:nueva_pregunta, _} ->
          # Preguntas solo a clientes (el servidor no juega)
          if node(pid) != get_server_node() or not es_servidor?() do
            send(pid, mensaje)
          end

        {:partida_iniciada, _} ->
          send(pid, mensaje)

        {:resultado_pregunta, _} ->
          if node(pid) != get_server_node() or not es_servidor?() do
            send(pid, mensaje)
          end

        {:partida_finalizada, _} ->
          send(pid, mensaje)

        _ ->
          if node(pid) != get_server_node() or not es_servidor?() do
            send(pid, mensaje)
          end
      end
    end)
  end

  defp notificar_jugador(estado, jugador, mensaje) do
    case Map.get(estado.procesos_escucha, jugador) do
      nil ->
        :ok
      pid ->
        if node(pid) != get_server_node() or not es_servidor?() do
          send(pid, mensaje)
        end
    end
  end

  ## FUNCIONES AUXILIARES.

  defp log_servidor(mensaje) do
    if Node.self() == get_server_node() do
      IO.puts(mensaje)
    end
  end

  defp guardar_resultado(estado, ranking) do
    File.mkdir_p!("data")
    timestamp = NaiveDateTime.local_now() |> NaiveDateTime.to_string()

    linea =
      "[#{timestamp}] Partida #{estado.id} | Tema: #{estado.tema} | Ranking: #{inspect(ranking)}\n"

    File.write!("data/resultados.log", linea, [:append])
  end
end
