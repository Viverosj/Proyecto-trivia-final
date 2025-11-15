defmodule QuestionBankTest do
  use ExUnit.Case
  alias QuestionBank

  @moduletag :question_bank

  describe "QuestionBank.cargar_preguntas/0" do
    test "carga correctamente las preguntas desde el archivo" do
      preguntas = QuestionBank.cargar_preguntas()

      assert is_list(preguntas)
      assert length(preguntas) > 0

      # Verifica que la estructura tenga los campos esperados
      primera = hd(preguntas)
      assert %QuestionBank{} = primera
      assert Map.has_key?(primera, :tema)
      assert Map.has_key?(primera, :texto)
      assert Map.has_key?(primera, :opciones)
      assert Map.has_key?(primera, :correcta)
    end
  end

  describe "QuestionBank.obtener_por_tema/1" do
    test "filtra correctamente las preguntas por tema" do
      tema = "historia"
      preguntas = QuestionBank.obtener_por_tema(tema) 

      assert Enum.all?(preguntas, fn p -> p.tema == tema end)
    end
  end

  describe "QuestionBank.obtener_aleatorias/2" do
    test "retorna la cantidad correcta de preguntas aleatorias" do
      tema = "historia"
      preguntas = QuestionBank.obtener_aleatorias(tema, 2)

      assert length(preguntas) == 2
      assert Enum.all?(preguntas, fn p -> p.tema == tema end)
    end

    test "no falla si se piden más preguntas de las que hay" do
      tema = "historia"
      preguntas = QuestionBank.obtener_aleatorias(tema, 100)

      assert is_list(preguntas)
      assert length(preguntas) > 0
    end
  end
end
