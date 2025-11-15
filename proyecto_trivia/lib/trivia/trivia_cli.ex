defmodule TriviaCLI do
  @moduledoc """
  Interfaz de línea de comandos (CLI) para el juego de Trivia.

  Este módulo funciona en dos modos:
  * SERVIDOR: Cuando no hay nodos conectados, actúa como servidor
  * CLIENTE: Cuando detecta nodos conectados, se conecta como cliente
  """

  alias UserManager
  alias GameServer
  alias DynamicSupervisor

  # INICIO Y CONFIGURACIÓN.

  def init_session do
    IO.puts("\n🎮 Bienvenido a BrainBattle modo TRIVIA 🎮\n")
    configurar_servidor()
    menu_principal()
  end

  # CONFIGURACIÓN DEL SERVIDOR

    # Configuración del modo de operacion (Servidor o Cliente).

  defp configurar_servidor do
    nodos_conectados = Node.list()

    cond do
      # Cliente
      length(nodos_conectados) > 0 ->
        servidor = List.first(nodos_conectados)
        GameServer.set_server_node(servidor)
        IO.puts("✅ Conectado al servidor: #{servidor}")
        IO.puts("📍 Este nodo (cliente): #{Node.self()}\n")

      # Servidor
      true ->
        GameServer.set_server_node(Node.self())
        IO.puts("🖥️ Este nodo es el servidor: #{Node.self()}\n")
    end
  end

  # MENU PRINCIPAL

  def menu_principal do
    IO.puts("""
    \n📜 MENÚ PRINCIPAL
    1. Registrarse
    2. Iniciar sesión
    3. Ver ranking general
    4. Ver ranking por tema
    5. Salir
    """)

    opcion = IO.gets("Selecciona una opción: ") |> String.trim()

    case opcion do
      "1" -> registrar_usuario()
      "2" -> iniciar_sesion()
      "3" -> mostrar_ranking_general()
      "4" -> mostrar_ranking_por_tema()
      "5" -> IO.puts("👋 ¡Gracias por jugar! Hasta pronto.\n")
      _ ->
        # Validación: Opcion inválida
        IO.puts("❌ Opción no válida.\n")
        menu_principal()
    end
  end

  # REGISTRO E INICIO DE SESIÓN (Validación de credenciales y estado del usuario)

  defp registrar_usuario do
    nombre = IO.gets("Nombre de usuario: ") |> String.trim()
    contrasena = IO.gets("Contraseña: ") |> String.trim()

    case UserManager.registrar_usuario(nombre, contrasena) do
      {:ok, msg} -> IO.puts("✅ #{msg}\n")
      {:error, msg} -> IO.puts("⚠️ #{msg}\n")
    end

    menu_principal()
  end

  defp iniciar_sesion do
    nombre = IO.gets("Usuario: ") |> String.trim()
    contrasena = IO.gets("Contraseña: ") |> String.trim()

    case UserManager.iniciar_sesion(nombre, contrasena) do
      {:ok, msg} ->
        IO.puts("✅ #{msg}\n")
        menu_juego(nombre)

      {:error, msg} ->
        IO.puts("⚠️ #{msg}\n")
        menu_principal()
    end
  end

  ## MENU DEL JUGADOR

  defp menu_juego(nombre) do
    IO.puts("""
    \n🎯 MENÚ DEL JUGADOR (#{nombre})
    1. Crear nueva partida
    2. Unirse a una partida existente
    3. Iniciar partida (si eres el creador)
    4. Ver puntaje
    5. Ver ranking general
    6. Ver ranking por tema
    7. Cerrar sesión
    """)

    opcion = IO.gets("Selecciona una opción: ") |> String.trim()

    case opcion do
      "1" -> crear_partida(nombre)
      "2" -> unirse_partida(nombre)
      "3" -> iniciar_partida(nombre)
      "4" -> ver_puntaje(nombre)
      "5" -> mostrar_ranking_general_jugador(nombre)
      "6" -> mostrar_ranking_por_tema_jugador(nombre)
      "7" ->
        IO.puts("👋 Sesión cerrada.\n")
        menu_principal()

      _ ->
        IO.puts("❌ Opción no válida.")
        menu_juego(nombre)
    end
  end

  ## GESTIÓN DE PARTIDAS

  defp crear_partida(nombre) do
    id = IO.gets("🔢 ID de la partida: ") |> String.trim()
    tema = IO.gets("📚 Tema: ") |> String.trim()
    num = IO.gets("❓ Número de preguntas: ") |> String.trim() |> String.to_integer()
    tiempo = IO.gets("⏱️ Tiempo por pregunta (segundos): ") |> String.trim() |> String.to_integer()

    IO.puts("\n🔄 Creando partida '#{id}' en el servidor...")
    IO.puts("   Servidor: #{inspect(Application.get_env(:trivia, :server_node))}")
    IO.puts("   Este nodo: #{inspect(Node.self())}")

    case GameServer.crear_partida_remota(id, tema, num, tiempo) do
      {:ok, pid} ->
        IO.puts("✅ Partida creada exitosamente")
        IO.puts("   PID: #{inspect(pid)}")

        Process.sleep(300)

        IO.puts("\n🔍 Verificando que la partida esté registrada...")
        existe = GameServer.partida_existe?(id)
        IO.puts("   Resultado: #{existe}")

        if existe do
          IO.puts("✅ Partida '#{id}' confirmada en el servidor\n")

          # Diferencia entre Servidor - Cliente
          server = Application.get_env(:trivia, :server_node)
          if Node.self() == server do
            # Servidor: Modo observador
            IO.puts("🖥️ Partida creada desde el servidor")
            IO.puts("📢 Los jugadores pueden unirse con ID: '#{id}'")
            IO.puts("💡 Cuando estés listo, usa la opción 3 para iniciar la partida.\n")
          else
            # Cliente: Se une como jugador
            case GameServer.unirse_a_partida(id, nombre) do
              {:ok, _} ->
                IO.puts("✅ #{nombre} se unió como jugador")
                IO.puts("📢 Partida lista. Otros jugadores pueden unirse con ID: '#{id}'")
                IO.puts("💡 Cuando estés listo, usa la opción 3 para iniciar la partida.\n")

              {:error, msg} ->
                IO.puts("⚠️ Error al unirse: #{msg}\n")
            end
          end
        else
          IO.puts("❌ Error: La partida fue creada pero no aparece en el Registry")
          IO.puts("   Esto puede indicar un problema de conexión o sincronización\n")
        end

      {:error, {:already_started, _pid}} ->
        IO.puts("⚠️ Ya existe una partida con el ID '#{id}'.")
        IO.puts("   Prueba con otro ID o únete a la existente.\n")

      {:badrpc, reason} ->
        IO.puts("❌ Error de conexión con el servidor: #{inspect(reason)}")
        IO.puts("    Servidor configurado: #{inspect(Application.get_env(:trivia, :server_node))}")
        IO.puts("    Nodos conectados: #{inspect(Node.list())}")
        IO.puts("    Verifica que estés conectado al nodo correcto.\n")

      error ->
        IO.puts("❌ Error al crear partida: #{inspect(error)}")
    end

    menu_juego(nombre)
  end

  defp unirse_partida(nombre) do
    IO.puts("\n📋 PARTIDAS DISPONIBLES:")
    server = Application.get_env(:trivia, :server_node)

    # Obtener la lista de partidas
    partidas = if Node.self() == server do
      GameSupervisor.listar_partidas()
    else
      resultado = :rpc.call(server, GameSupervisor, :listar_partidas, [])
      case resultado do
        {:badrpc, _} -> []
        lista -> lista
      end
    end

    # Filtrar partidas disponibles (con menos de 4 jugadores y en estado :esperando)
    partidas_disponibles = Enum.filter(partidas, fn
      {_id, %{jugadores: jugadores, estado: estado}} ->
        estado == :esperando and length(jugadores) < 4
      _ ->
        false
    end)

    if partidas_disponibles == [] do
      IO.puts("   ⚠️ No hay partidas disponibles en este momento.\n")
      IO.puts("💡 Crea una nueva partida con la opción 1\n")
      menu_juego(nombre)
    else
      # Mostrar partidas disponibles
      Enum.each(partidas_disponibles, fn {id, %{jugadores: jugadores, tema: tema}} ->
        num_jugadores = length(jugadores)
        IO.puts("   🎯 ID: '#{id}' | Tema: #{tema} | Jugadores: #{num_jugadores}/4")
      end)

      IO.puts("")
      id = IO.gets("🔢 ID de la partida a unirse: ") |> String.trim()

      IO.puts("\n🔍 Buscando partida en el servidor...")
      IO.puts("   Servidor: #{inspect(server)}")

      if GameServer.partida_existe?(id) do
        IO.puts("✅ Partida encontrada")

        case GameServer.unirse_a_partida(id, nombre) do
          {:ok, msg} ->
            IO.puts("✅ #{msg}")
            IO.puts("📢 Esperando a que el creador inicie la partida...")
            IO.puts("⏳ Te quedarás en modo de espera automáticamente.\n")

            esperar_y_jugar(id, nombre)

          {:error, msg} ->
            IO.puts("⚠️ #{msg}\n")
            menu_juego(nombre)
        end
      else
        IO.puts("❌ No existe una partida con ese ID en el servidor")
        IO.puts("   Verifica:")
        IO.puts("   1. Que el ID sea correcto")
        IO.puts("   2. Que estés conectado al servidor correcto")
        IO.puts("   3. Que la partida haya sido creada\n")
        menu_juego(nombre)
      end
    end
  end

  defp iniciar_partida(nombre) do
    id = IO.gets("🔢 ID de la partida a iniciar: ") |> String.trim()

    case GameServer.iniciar(id) do
      {:ok, msg} ->
        IO.puts("🚀 #{msg}\n")

        # Si estamos en el servidor, NO entramos en modo de juego
        server = Application.get_env(:trivia, :server_node)
        if Node.self() == server do
          IO.puts("🖥️ Partida iniciada desde el servidor")
          IO.puts("📊 Observando la partida...\n")
          modo_observador(id, nombre)
        else
          # Solo los clientes entran en modo de juego activo
          modo_juego_asincrono(id, nombre)
        end

      {:error, msg} ->
        IO.puts("⚠️ #{msg}\n")
        menu_juego(nombre)
    end
  end

  ## RANKING Y PUNTAJE

  defp ver_puntaje(nombre) do
    case UserManager.ver_puntaje(nombre) do
      {:ok, p} -> IO.puts("⭐ Puntaje total de #{nombre}: #{p}\n")
      {:error, msg} -> IO.puts("⚠️ #{msg}\n")
    end

    menu_juego(nombre)
  end

    # Versión para cuando estás en el menú inicial.

  defp mostrar_ranking_general do
    IO.puts("\n🏆 RANKING GENERAL:")
    ranking = UserManager.ver_ranking()

    if ranking == [] do
      IO.puts("No hay usuarios registrados todavía.\n")
    else
      Enum.each(ranking, fn {nombre, puntos} ->
        IO.puts("- #{nombre}: #{puntos} puntos")
      end)
    end

    IO.puts("")
    menu_principal()
  end

    # Versión para cuando estás en el menú de jugador.

  defp mostrar_ranking_general_jugador(nombre) do
    IO.puts("\n🏆 RANKING GENERAL:")
    ranking = UserManager.ver_ranking()

    if ranking == [] do
      IO.puts("No hay usuarios registrados todavía.\n")
    else
      Enum.each(ranking, fn {nom, puntos} ->
        IO.puts("- #{nom}: #{puntos} puntos")
      end)
    end

    IO.puts("")
    menu_juego(nombre)
  end

    # Versión para cuando estás en el menú inicial.

  defp mostrar_ranking_por_tema do
    tema = IO.gets("Ingrese el nombre del tema: ") |> String.trim()
    IO.puts("\n🏅 RANKING POR TEMA: #{String.capitalize(tema)}")

    ranking = UserManager.ver_ranking_por_tema(tema)

    if ranking == [] do
      IO.puts("No hay puntajes registrados para este tema.\n")
    else
      Enum.each(ranking, fn {nombre, puntos} ->
        IO.puts("- #{nombre}: #{puntos} puntos")
      end)
    end

    IO.puts("")
    menu_principal()
  end

  # Versión para cuando estás en el menú de jugador.

  defp mostrar_ranking_por_tema_jugador(nombre) do
    tema = IO.gets("Ingrese el nombre del tema: ") |> String.trim()
    IO.puts("\n🏅 RANKING POR TEMA: #{String.capitalize(tema)}")

    ranking = UserManager.ver_ranking_por_tema(tema)

    if ranking == [] do
      IO.puts("No hay puntajes registrados para este tema.\n")
    else
      Enum.each(ranking, fn {nom, puntos} ->
        IO.puts("- #{nom}: #{puntos} puntos")
      end)
    end

    IO.puts("")
    menu_juego(nombre)
  end

  ## MODO DE JUEGO ASÍNCRONO

  defp modo_juego_asincrono(id_partida, jugador) do
    parent = self()

    # Crear el proceso listener
    listener_pid = spawn(fn ->
      proceso_listener(id_partida, jugador, parent)
    end)

    # CRÍTICO: Registrar el listener solo si realmente vamos a escuchar
    case GameServer.registrar_escucha(id_partida, jugador, listener_pid) do
      {:ok, _msg} ->
        :ok
      {:error, msg} ->
        IO.puts("❌ Error al registrar listener: #{msg}")
    end

    IO.puts("🎮 Modo de juego iniciado. Escribe 'answer N OPCION' para responder")
    IO.puts("   Ejemplo: answer 1 b")
    IO.puts("   Escribe 'salir' para abandonar\n")

    loop_input_usuario(id_partida, jugador, listener_pid)
  end

  defp proceso_listener(id_partida, jugador, parent) do
    receive do
      {:nueva_pregunta, texto} ->
        IO.puts(texto)
        proceso_listener(id_partida, jugador, parent)

      {:resultado_pregunta, texto} ->
        IO.puts(texto)
        proceso_listener(id_partida, jugador, parent)

      {:respuesta_recibida, _texto} ->
        proceso_listener(id_partida, jugador, parent)

      {:partida_iniciada, texto} ->
        IO.puts(texto)
        proceso_listener(id_partida, jugador, parent)

      {:partida_finalizada, texto} ->
        IO.puts(texto)
        send(parent, :juego_finalizado)
        :ok

      :terminar ->
        :ok
    end
  end

  defp loop_input_usuario(id_partida, jugador, listener_pid) do
    receive do
      :juego_finalizado ->
        IO.puts("\n👋 Regresando al menú principal...")
        Process.sleep(2000)
        send(listener_pid, :terminar)
        menu_principal()
    after
      0 ->
        :ok
    end

    case IO.gets("") do
      :eof ->
        loop_input_usuario(id_partida, jugador, listener_pid)

      input ->
        input = String.trim(input)

        cond do
          input == "" ->
            loop_input_usuario(id_partida, jugador, listener_pid)

          String.starts_with?(String.downcase(input), "answer") ->
            procesar_respuesta(input, id_partida, jugador)
            loop_input_usuario(id_partida, jugador, listener_pid)

          String.downcase(input) in ["exit", "salir"] ->
            IO.puts("👋 Saliendo del modo de respuestas...")
            send(listener_pid, :terminar)
            menu_principal()

          true ->
            loop_input_usuario(id_partida, jugador, listener_pid)
        end
    end
  end

  defp procesar_respuesta(input, id_partida, jugador) do
    partes = String.split(input, " ")

    case partes do
      [_cmd, _num, opcion] ->
        opcion_num =
          opcion
          |> String.downcase()
          |> case do
            "a" -> "1"
            "b" -> "2"
            "c" -> "3"
            "d" -> "4"
            otro -> otro
          end

        case GameServer.responder(id_partida, jugador, opcion_num) do
          {:ok, _} ->
            IO.puts("✅ Respuesta enviada")
          {:error, msg} ->
            IO.puts("⚠️ #{msg}")
        end

      _ ->
        IO.puts("⚠️ Formato inválido. Usa: answer 1 b")
    end
  end

  def esperar_y_jugar(id_partida, jugador) do
    IO.puts("⏳ Esperando que inicie la partida...")
    IO.puts("💡 Tip: El creador debe usar la opción 3 para iniciar.\n")

    modo_juego_asincrono(id_partida, jugador)
  end

  # MODO OBSERVADOR.

  defp modo_observador(id_partida, nombre) do
    parent = self()

    listener_pid = spawn(fn ->
      proceso_observador(parent)
    end)

    GameServer.registrar_escucha(id_partida, nombre, listener_pid)

    IO.puts("📊 Modo observador activo")
    IO.puts("💡 Escribe 'salir' para volver al menú\n")

    loop_observador(listener_pid)
  end

  defp proceso_observador(parent) do
    receive do
      {:partida_iniciada, texto} ->
        IO.puts(texto)
        proceso_observador(parent)

      {:partida_finalizada, texto} ->
        IO.puts(texto)
        send(parent, :juego_finalizado)
        :ok

      :terminar ->
        :ok

      _ ->
        proceso_observador(parent)
    end
  end

  defp loop_observador(listener_pid) do
    receive do
      :juego_finalizado ->
        IO.puts("\n👋 Regresando al menú principal...")
        Process.sleep(2000)
        send(listener_pid, :terminar)
        menu_principal()
    after
      0 ->
        :ok
    end

    case IO.gets("") do
      :eof ->
        loop_observador(listener_pid)

      input ->
        input = String.trim(input)

        if String.downcase(input) in ["exit", "salir"] do
          IO.puts("👋 Saliendo del modo observador...")
          send(listener_pid, :terminar)
          menu_principal()
        else
          loop_observador(listener_pid)
        end
    end
  end

  def start(), do: init_session()
end
