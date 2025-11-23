import { useState } from "react";
import { useNavigate } from "react-router";
import { useAuthStore } from "../store/useAuthStore";

const API_URL = "http://3.144.152.48/api";

export default function Login() {
  const { setAuth } = useAuthStore();
  const navigate = useNavigate();

  const [mode, setMode] = useState("login"); // login o register
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();

    try {
      let url = `${API_URL}/auth/login`;
      let body = { email, password };

      if (mode === "register") {
        url = `${API_URL}/auth/register`;
        body = { name, email, password, role: "student" }; // solo estudiantes
      }

      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.message || "Error en la operación");
      }

      const data = await res.json();

      if (mode === "login") {
        // Guardar token y role en store
        setAuth({
          token: data.token,
          role: data.role,
          userId: data.userId,
          name: data.name,
        });

        // Redirigir según role
        switch (data.role) {
          case "teacher":
            navigate("/teacher/home");
            break;
          case "student":
            navigate("/student/home");
            break;
          case "admin":
            navigate("/admin/home");
            break;
          default:
            navigate("/");
        }
      } else {
        // Registro exitoso -> volver a login
        setMode("login");
        setName("");
        setEmail("");
        setPassword("");
        setError("Registro exitoso, inicia sesión");
      }
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex justify-center items-center min-h-screen bg-gray-100">
      <form
        onSubmit={handleSubmit}
        className="bg-white p-6 rounded-md shadow-md w-full max-w-sm"
      >
        <h2 className="text-2xl font-bold mb-4 text-center">
          {mode === "login" ? "Iniciar Sesión" : "Registrar Estudiante"}
        </h2>

        {error && <div className="text-red-500 mb-2">{error}</div>}

        {mode === "register" && (
          <input
            type="text"
            placeholder="Nombre completo"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full mb-2 px-3 py-2 border rounded-md"
            required
          />
        )}

        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full mb-2 px-3 py-2 border rounded-md"
          required
        />

        <input
          type="password"
          placeholder="Contraseña"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full mb-4 px-3 py-2 border rounded-md"
          required
        />

        <button
          type="submit"
          className="w-full bg-blue-600 text-white py-2 rounded-md hover:bg-blue-700"
        >
          {mode === "login" ? "Entrar" : "Registrar"}
        </button>

        <div className="text-center mt-4">
          {mode === "login" ? (
            <button
              type="button"
              onClick={() => {
                setMode("register");
                setError("");
              }}
              className="text-blue-600 hover:underline text-sm"
            >
              ¿No tienes cuenta? Regístrate
            </button>
          ) : (
            <button
              type="button"
              onClick={() => {
                setMode("login");
                setError("");
              }}
              className="text-blue-600 hover:underline text-sm"
            >
              Volver al login
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
