defmodule TriviaTest do
  use ExUnit.Case
  alias UserManager
  alias GameServer

  @moduledoc """
  ✅ Pruebas automáticas del proyecto Trivia Elixir.
  Verifica el correcto funcionamiento de los módulos:
  - UserManager
  - GameServer
  """

  setup do
    # Limpiamos antes de cada test
    UserManager.reset()
    :ok
  end

  # ------------------------------------------------------------------
  # TESTS DE USUARIOS
  # ------------------------------------------------------------------

  test "UserManager registra usuarios correctamente" do
    UserManager.reset()
    assert {:ok, _msg} = UserManager.registrar_usuario("juanita", "1234")
    assert {:error, _msg} = UserManager.registrar_usuario("juanita", "1234")
  end

  test "UserManager permite iniciar sesión con credenciales correctas" do
    UserManager.reset()
    UserManager.registrar_usuario("juanita", "1234")

    assert {:ok, _msg} = UserManager.iniciar_sesion("juanita", "1234")
    assert {:error, _msg} = UserManager.iniciar_sesion("juanita", "malpass")
  end

  test "UserManager actualizar y ver puntaje" do
    UserManager.reset()
    UserManager.registrar_usuario("juanita", "1234")

    UserManager.actualizar_puntaje("juanita", 20)
    assert {:ok, 20} = UserManager.ver_puntaje("juanita")
  end

  test "UserManager ranking general muestra usuarios con puntajes" do
    UserManager.reset()
    UserManager.registrar_usuario("juanita", "1234")
    UserManager.registrar_usuario("carlos", "abcd")
    UserManager.actualizar_puntaje("juanita", 30)
    UserManager.actualizar_puntaje("carlos", 10)

    ranking = UserManager.ver_ranking()
    assert Enum.any?(ranking, fn {u, p} -> u == "juanita" and p == 30 end)
    assert Enum.any?(ranking, fn {u, p} -> u == "carlos" and p == 10 end)
  end

  # ------------------------------------------------------------------
  # TESTS DE PARTIDAS (GameServer)
  # ------------------------------------------------------------------

  test "GameServer crea y maneja una partida" do 
    id = "test_game"
    tema = "historia"

    {:ok, pid} =
      DynamicSupervisor.start_child(GameSupervisor, {
        GameServer,
        [id: id, tema: tema, num_preguntas: 2, tiempo: 1]
      })

    GameServer.unirse_a_partida(id, "juanita")
    GameServer.unirse_a_partida(id, "carlos")

    # La función :info devuelve directamente el estado
    estado = GenServer.call(pid, :info)

    assert estado.id == id
    assert "juanita" in estado.jugadores
    assert "carlos" in estado.jugadores
    assert estado.tema == tema
  end
end
