# 🎮 Trivia Multijugador en Elixir

Este proyecto implementa un **juego de trivia multijugador concurrente** desarrollado en **Elixir**, utilizando procesos supervisados con `GenServer`, `DynamicSupervisor` y un sistema de registro de usuarios y partidas.  

Permite crear partidas, unirse a ellas, responder preguntas en tiempo real y guardar los resultados en archivos de log.

---

## 🚀 Características principales

- ✅ Soporte multijugador con procesos concurrentes.
- 🧠 Banco de preguntas por categorías (Ciencia, Historia, etc.).
- 🧍 Registro e inicio de sesión de usuarios.
- ⚙️ Sistema de partidas dinámicas (`GameServer` supervisadas por `GameSupervisor`).
- 🕒 Control de tiempo por pregunta.
- 📈 Ranking y puntajes globales persistentes.
- 💾 Registro de resultados en archivo `results.log`.
- 💬 Menú interactivo en consola (`TriviaCLI`).

---

## 📦 Requisitos previos

Antes de ejecutar el proyecto, asegúrate de tener instalado:

- [Elixir](https://elixir-lang.org/install.html) versión **1.15 o superior**
- [Erlang/OTP](https://www.erlang.org/downloads) correspondiente
- (Opcional) Editor recomendado: **Visual Studio Code** con la extensión *ElixirLS*

---

## ⚙️ Instalación

1. Clona el repositorio o copia el proyecto:
   ```bash
   git clone https://github.com/tu_usuario/trivia_elixir.git
   cd trivia_elixir
   ```

2. Instala las dependencias:
   ```bash
   mix deps.get
   ```

3. Compila el proyecto:
   ```bash
   mix compile
   ```

---

## ▶️ Ejecución del proyecto

1. Inicia la consola interactiva:
   ```bash
   iex -S mix
   ```

2. El sistema mostrará el mensaje inicial:
   ```
   🚀 Iniciando servidor de Trivia...
   Usa:
     iex> TriviaCLI.start()
   para comenzar el menú interactivo.
   ```

3. Inicia el menú principal:
   ```elixir
   TriviaCLI.start()
   ```

---

## 🧩 Menú principal

```
🎮 Bienvenido a *TRIVIA ELIXIR* 🎮

📜 MENÚ PRINCIPAL
1. Registrarse
2. Iniciar sesión
3. Salir
```

Después de iniciar sesión, verás el **menú del jugador:**

```
1. Crear partida nueva
2. Unirse a partida existente
3. Consultar mi puntaje
4. Consultar ranking histórico
5. Salir
```

---

## 🕹️ Flujo de juego – Ejemplo

1. **Pedro** y **Carlos** se conectan al servidor.
2. Pedro crea una partida de **Ciencia** con 5 preguntas y 15 segundos por pregunta.
3. Carlos se une a la partida.
4. El sistema anuncia:

   ```
   Pregunta 1: ¿Cuál es el planeta más grande del sistema solar?
   A) Marte
   B) Júpiter
   C) Saturno
   D) Neptuno
   Tiempo: 15 segundos
   ```

5. Pedro responde:
   ```
   answer 1 B
   → Correcto, +10 puntos
   ```

6. Carlos responde:
   ```
   answer 1 C
   → Incorrecto, -5 puntos
   ```

7. Al finalizar las preguntas, se muestra el ranking:

   ```
   Pedro: 40 puntos
   Carlos: -10 puntos
   🏆 Ganador: Pedro
   ```

8. El resultado se guarda automáticamente en `results.log` y se actualizan los puntajes globales.

---

## 🧱 Estructura del proyecto

```
lib/
├── trivia_app.ex          # Punto de entrada principal
├── trivia_cli.ex          # Interfaz de línea de comandos
├── game_server.ex         # Proceso GenServer para cada partida
├── game_supervisor.ex     # Supervisor dinámico de partidas
├── user_manager.ex        # Manejo de usuarios y puntajes
├── question_bank.ex       # Banco de preguntas
└── game.ex                # Lógica de juego (versión individual)
```

---

## 🧾 Archivos importantes

| Archivo | Descripción |
|----------|-------------|
| `results.log` | Registro de partidas finalizadas (puntajes y ganadores). |
| `questions.txt` | Banco de preguntas, formato: `categoria;pregunta;opciones;respuesta_correcta`. |
| `users.txt` | Registro persistente de usuarios y puntajes. |

---

## 🔍 Ejemplo de banco de preguntas (`questions.txt`)

```
ciencia;¿Cuál es el planeta más grande del sistema solar?;Marte,Júpiter,Saturno,Neptuno;2
historia;¿En qué año comenzó la Segunda Guerra Mundial?;1939,1945,1914,1929;1
deportes;¿Cuántos jugadores tiene un equipo de fútbol?;10,11,9,12;2
```

---

## 🧑‍💻 Ejemplo rápido de uso en consola

```elixir
iex> TriviaCLI.start()
🎮 Bienvenido a *TRIVIA ELIXIR* 🎮

1. Registrarse
2. Iniciar sesión
3. Salir
> 1
Ingrese su nombre de usuario: pedro
Ingrese su contraseña: 123

Usuario registrado exitosamente ✅

> 2
Usuario: pedro
Contraseña: 123

🎯 MENÚ DEL JUGADOR
1. Crear partida nueva
2. Unirse a partida existente
...
```

---

## 🧩 Estructura de supervisión

```
TriviaApp (Supervisor)
│
├── UserManager (GenServer)
├── QuestionBank (GenServer)
└── GameSupervisor (DynamicSupervisor)
      ├── GameServer (Partida 1)
      ├── GameServer (Partida 2)
      └── ...
```

---

## 🧠 Conceptos de Elixir aplicados

- **GenServer** → Manejo del estado de cada partida.
- **DynamicSupervisor** → Creación y finalización dinámica de procesos de juego.
- **Registry** → Registro único de partidas activas.
- **Procesamiento concurrente** → Cada partida corre en un proceso independiente.
- **Persistencia simple** → Archivos de texto (`.txt`, `.log`) para usuarios y resultados.

---

## 🧾 Créditos

Proyecto desarrollado como parte del curso **Programación III – Universidad de Nariño**,  
por *[tu nombre]*.

---

## 📄 Licencia

Este proyecto se distribuye bajo la licencia **MIT**.
