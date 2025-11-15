defmodule Game do
  @moduledoc """
  Módulo que existe para juego local.
  """

  alias QuestionBank

  defstruct [
    :jugador,
    :puntaje,
    :preguntas,
    :actual,
    :tema
  ]

  ## INICIO DE JUEGO.

  def jugar(nombre, tema \\ "ciencia") do
    IO.puts("🎮 Comienza el juego para #{nombre} (tema: #{tema})!\n")

    preguntas = QuestionBank.obtener_aleatorias(tema, 3)

    if preguntas == [] do
      IO.puts("⚠️ No hay preguntas disponibles para el tema '#{tema}'.")
    else
      estado = %Game{
        jugador: nombre,
        puntaje: 0,
        preguntas: preguntas,
        actual: 1,
        tema: tema
      }

      hacer_pregunta(estado)
    end
  end

  ## MOSTRAR PREGUNTAS Y PROCESAR RESPUESTAS

  defp hacer_pregunta(%Game{preguntas: preguntas, actual: num, puntaje: puntos, jugador: nombre, tema: tema} = estado) do
    if num > length(preguntas) do
      IO.puts("\n✅ Juego terminado. Puntaje final: #{puntos}")

      guardar_resultado(nombre, tema, puntos, length(preguntas))
    else
      pregunta = Enum.at(preguntas, num - 1)

      IO.puts("\n❓ #{pregunta.texto}")
      Enum.each(Enum.with_index(pregunta.opciones, 1), fn {opcion, i} ->
        IO.puts("  #{i}. #{opcion}")
      end)

      respuesta = IO.gets("👉 Tu respuesta: ") |> String.trim()

      nuevo_estado =
        if String.to_integer(respuesta) == pregunta.correcta do
          IO.puts("🎉 ¡Correcto! +10 puntos.")
          %{estado | puntaje: puntos + 10, actual: num + 1}
        else
          IO.puts("❌ Incorrecto. -5 puntos.")
          %{estado | puntaje: puntos - 5, actual: num + 1}
        end

      hacer_pregunta(nuevo_estado)
    end
  end

  ## PERSISTENCIA DE RESULTADOS

  defp guardar_resultado(nombre, tema, puntaje, total) do
    # Asegura de que la carpeta data exista
    File.mkdir_p!("data")

    timestamp = NaiveDateTime.local_now() |> NaiveDateTime.to_string()
    linea = "[#{timestamp}] Usuario: #{nombre} | Tema: #{tema} | Puntaje: #{puntaje}/#{total}\n"

    File.write!("data/resultados.log", linea, [:append])
  end
end
