defmodule QuestionBank do
  @moduledoc """
  Módulo responsable de cargar preguntas, filtrar preguntas por tema y seleccionar preguntas aleatorias
  """

  @ruta "data/questions.dat"

  ## ESTRUCTURA DE DATOS

  defstruct [
    :tema,
    :texto,
    :opciones,
    :correcta
  ]

  ## FUNCIONES DE CARGA Y FILTRADO

    # Carga preguntas desde el archivo, valida su formato,
    # convierte datos, ignora líneas inválidas y retorna una lista de preguntas o [] si hay errores.

  def cargar_preguntas do
    case File.read(@ruta) do
      {:ok, contenido} ->
        contenido
        |> String.split("\n", trim: true)
        |> Enum.map(&String.split(&1, ","))
        |> Enum.map(fn
          # VALIDACIÓN: Solo acepta líneas con exactamente 7 campos
          [tema, texto, o1, o2, o3, o4, correcta] ->
            %QuestionBank{
              tema: tema,
              texto: texto,
              opciones: [o1, o2, o3, o4],
              correcta: String.to_integer(String.trim(correcta))

            }

          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      {:error, _} ->
        IO.puts("❌ No se pudo leer el archivo de preguntas.")
        []
    end
  end

    # Filtra preguntas por tema.

  def obtener_por_tema(tema) do
    cargar_preguntas()
    |> Enum.filter(fn pregunta -> pregunta.tema == tema end)
  end

    # Obtiene x preguntas aleatorias por tema.
    
  def obtener_aleatorias(tema, cantidad \\ 3) do
    obtener_por_tema(tema)
    |> Enum.shuffle()
    |> Enum.take(cantidad)
  end
end
