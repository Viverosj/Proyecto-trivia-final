defmodule UserManager do
  @moduledoc """
  Módulo para manejar usuarios del juego de trivia.

  Permite:
  * Registro y autenticación de usuarios
  * Gestión de puntajes globales y por tema
  * Persistencia en archivo binario `data/users.dat`
  * Rankings generales y por categoría

    Persistencia:
  * Los datos se guardan en formato binario (term_to_binary)
  * Cada operación de escritura actualiza el archivo inmediatamente
  * Los datos sobreviven al cierre de la aplicación
  """

  use Agent
  @ruta_archivo "data/users.dat"
  @directorio "data"

  ## INCIALIZACIÓN DEL ANGENT

  def start_link(_opciones \\ []) do
    File.mkdir_p!(@directorio)

    Agent.start_link(fn -> cargar_usuarios() end, name: __MODULE__)
  end

  ## CARGA Y GUARDADO DE LA PERSISTENCIA

  defp cargar_usuarios do
    case File.read(@ruta_archivo) do
      {:ok, datos_binarios} ->
        IO.puts("✅ Usuarios cargados desde #{@ruta_archivo}")
        :erlang.binary_to_term(datos_binarios)

      {:error, :enoent} ->
        IO.puts("📁 Creando nuevo archivo de usuarios...")
        %{}

      {:error, reason} ->
        IO.puts("⚠️ Error al cargar usuarios: #{inspect(reason)}")
        %{}
    end
  end

  defp guardar_usuarios(usuarios) do
    File.mkdir_p!(@directorio)

    datos_binarios = :erlang.term_to_binary(usuarios)

    case File.write(@ruta_archivo, datos_binarios) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.puts("❌ Error al guardar usuarios: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## API DE REGISTRO Y AUTENTICACIÓN.

  def registrar_usuario(nombre, contrasena) do
    Agent.get_and_update(__MODULE__, fn usuarios ->
      if Map.has_key?(usuarios, nombre) do
        {{:error, "El usuario ya existe"}, usuarios}
      else
        nuevo_usuario = %{
          nombre: nombre,
          contrasena: contrasena,
          puntaje: 0,
          temas: %{}
        }

        nuevos_usuarios = Map.put(usuarios, nombre, nuevo_usuario)

        case guardar_usuarios(nuevos_usuarios) do
          :ok ->
            {{:ok, "Usuario registrado correctamente"}, nuevos_usuarios}

          {:error, _reason} ->
            {{:error, "Error al guardar el usuario"}, usuarios}
        end
      end
    end)
  end

    # Auntetica un usuario con credenciales.

  def iniciar_sesion(nombre, contrasena) do
    Agent.get(__MODULE__, fn usuarios ->
      case Map.get(usuarios, nombre) do
        nil -> {:error, "El usuario no existe"}
        %{contrasena: ^contrasena} -> {:ok, "Inicio de sesión exitoso"}
        _ -> {:error, "Contraseña incorrecta"}
      end
    end)
  end

  ## API DE GESTIÓN DE PUNTAJES

  def ver_puntaje(nombre) do
    Agent.get(__MODULE__, fn usuarios ->
      case Map.get(usuarios, nombre) do
        nil -> {:error, "Usuario no encontrado"}
        %{puntaje: p} -> {:ok, p}
      end
    end)
  end

  # Actualizar puntaje global y por tema.
  def actualizar_puntaje(nombre, cambio, tema \\ nil) do
    Agent.get_and_update(__MODULE__, fn usuarios ->
      case Map.get(usuarios, nombre) do
        nil ->
          {{:error, "Usuario no encontrado"}, usuarios}

        usuario ->
          # Actualizar puntaje global.
          nuevo_puntaje = usuario.puntaje + cambio

          # Actualizar puntaje por tema si se especifica.
          nuevos_temas =
            if tema do
              Map.update(usuario.temas, tema, cambio, &(&1 + cambio))
            else
              usuario.temas
            end

          usuario_actualizado = %{usuario | puntaje: nuevo_puntaje, temas: nuevos_temas}
          nuevos_usuarios = Map.put(usuarios, nombre, usuario_actualizado)

          guardar_usuarios(nuevos_usuarios)

          {{:ok, "Nuevo puntaje total: #{nuevo_puntaje}"}, nuevos_usuarios}
      end
    end)
  end

  ## RANKING GENERAL.

  def ver_ranking do
    Agent.get(__MODULE__, fn usuarios ->
      usuarios
      |> Enum.map(fn {nombre, datos} -> {nombre, datos.puntaje} end)
      |> Enum.sort_by(fn {_nombre, puntaje} -> -puntaje end)
    end)
  end

  ## RANKING POR TEMA.

  def ver_ranking_por_tema(tema) do
    Agent.get(__MODULE__, fn usuarios ->
      usuarios
      |> Enum.map(fn {nombre, datos} ->
        puntos = Map.get(datos.temas, tema, 0)
        {nombre, puntos}
      end)
      |> Enum.reject(fn {_n, p} -> p == 0 end)
      |> Enum.sort_by(fn {_nombre, puntaje} -> -puntaje end)
    end)
  end


  def guardar_ahora do
    Agent.get(__MODULE__, fn usuarios ->
      case guardar_usuarios(usuarios) do
        :ok ->
          IO.puts("✅ Usuarios guardados manualmente")
          {:ok, "Datos guardados"}

        {:error, reason} ->
          {:error, "Error al guardar: #{inspect(reason)}"}
      end
    end)
  end

  def listar_usuarios do
    Agent.get(__MODULE__, fn usuarios ->
      Map.keys(usuarios)
    end)
  end

  def reset do
    Agent.update(__MODULE__, fn _ ->
      nuevos = %{}
      guardar_usuarios(nuevos)
      nuevos
    end)

    IO.puts("✅ Todos los usuarios han sido eliminados del sistema.")
    :ok
  end
end
