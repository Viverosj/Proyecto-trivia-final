defmodule TriviaApp do
  @moduledoc """
  Aplicación principal del servidor de Trivia.
  Inicia:
    * Registry global: Registro único de todas las partidas activas.
    * UserManager: Agente que maneja la persistencia de usuarios.
    * GameSupervisor: Supervisor dinámico que crea/supervisa partidas
  """

  use Application

    # Función de callback ejecutada automáticamente al iniciar la aplicación.

  def start(_type, _args) do
    children = [
      # Registro global de partidas (solo una vez)
      {Registry, keys: :unique, name: :game_registry},

      # Agente que maneja los usuarios
      UserManager,

      # Supervisor dinámico para las partidas
      {DynamicSupervisor, strategy: :one_for_one, name: GameSupervisor}
    ]

    IO.puts("""
    🚀 Iniciando servidor de Trivia...
    ---------------------------------
    Nodo actual: #{Node.self()}

    Usa:
      iex> TriviaCLI.start()
    para comenzar el juego.
    """)

    # Validación: Supervisa que todos los children inicien correctamente
    opts = [strategy: :one_for_one, name: Trivia.Supervisor]
    Supervisor.start_link(children, opts)
    # Servidor completamente inicado.
  end
end
