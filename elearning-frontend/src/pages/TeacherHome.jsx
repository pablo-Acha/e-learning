import { useEffect, useState } from "react";
import TeacherNavbar from "../components/TeacherNavBar";
import { Plus } from "lucide-react";
import ModuleForm from "../components/ModuleForm";
import { useAuthStore } from "../store/useAuthStore";

const API_URL = "http://3.19.223.47/api";

export default function TeacherHome() {
  const { token } = useAuthStore();
  const [classes, setClasses] = useState([]);
  const [showCreateClass, setShowCreateClass] = useState(false);
  const [newClass, setNewClass] = useState({ title: "", description: "" });
  const [selectedClass, setSelectedClass] = useState(null);
  const [showCreateModule, setShowCreateModule] = useState(false);
  const [moduleToEdit, setModuleToEdit] = useState(null);

  useEffect(() => {
    fetchClasses();
  }, []);

  const fetchClasses = async () => {
    try {
      const res = await fetch(`${API_URL}/teacher/classes`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      setClasses(data);
    } catch (err) {
      console.error(err);
    }
  };

  const createClass = async () => {
    try {
      const res = await fetch(`${API_URL}/classes`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(newClass),
      });
      if (res.ok) {
        setNewClass({ title: "", description: "" });
        setShowCreateClass(false);
        fetchClasses();
      }
    } catch (err) {
      console.error(err);
    }
  };
const createModuleOrUpdate = async (moduleData) => {
  try {
    if (moduleToEdit) {
      // Actualizar módulo existente (solo título y descripción)
      const res = await fetch(`${API_URL}/modules/${moduleToEdit.id}/video`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          title: moduleData.title,
          description: moduleData.description,
        }),
      });

      if (!res.ok) throw new Error("Error actualizando módulo");

      const updatedModule = await res.json();

      // Actualizar estado
      setClasses((prev) =>
        prev.map((cls) =>
          cls.id === selectedClass.id
            ? {
                ...cls,
                modules: cls.modules.map((m) =>
                  m.id === updatedModule.id ? updatedModule : m
                ),
              }
            : cls
        )
      );

    } else {
      // Crear módulo nuevo con video
      await createModule(moduleData);
    }

    // Reset
    setShowCreateModule(false);
    setModuleToEdit(null);
    setSelectedClass(null);

  } catch (err) {
    console.error(err);
    alert(err.message);
  }
};
  // Eliminar módulo
const handleDeleteModule = async (mod, cls) => {
  if (!confirm(`¿Seguro que quieres eliminar "${mod.title}"?`)) return;

  try {
    const res = await fetch(`${API_URL}/modules/${mod.id}/video`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw new Error("Error eliminando módulo");

    setClasses(prev =>
      prev.map(c =>
        c.id === cls.id
          ? { ...c, modules: c.modules.filter(m => m.id !== mod.id) }
          : c
      )
    );
  } catch (err) {
    console.error(err);
    alert("No se pudo eliminar el módulo");
  }
};
// Editar módulo
const handleEditModule = (mod, cls) => {
  setSelectedClass(cls);
  setModuleToEdit(mod);
  setShowCreateModule(true);
};


  const createModule = async (moduleData) => {
    try {
      // Validar que haya un archivo de video
      if (!moduleData.videoFile) {
        alert("Debes subir un video para crear el módulo.");
        return;
      }

      // 1. Crear módulo sin video (temporal)
      const res = await fetch(
        `${API_URL}/classes/${selectedClass.id}/modules`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({
            title: moduleData.title,
            description: moduleData.description,
            order: 5,
            videoUrl: null, // se actualizará luego
          }),
        }
      );

      if (!res.ok) throw new Error("Error creando módulo");
      const module = await res.json();

      // 2. Subir video
      const formData = new FormData();
      formData.append("video", moduleData.videoFile);

      const uploadRes = await fetch(`${API_URL}/modules/${module.id}/video`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
        body: formData,
      });

      if (!uploadRes.ok) throw new Error("Error subiendo video");

      const updatedModule = await uploadRes.json();

      // Actualizar estado
      setClasses((prev) =>
        prev.map((cls) =>
          cls.id === selectedClass.id
            ? { ...cls, modules: [...cls.modules, updatedModule] }
            : cls
        )
      );

      setShowCreateModule(false);
      setSelectedClass(null);
    } catch (err) {
      console.error(err);
    }
  };


  return (
    <div className="min-h-screen bg-gray-100">
      {/* <TeacherNavbar /> */}
      <div className="p-6 mt-6 max-w-6xl mx-auto">
        {/* Crear Clase */}
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold">Miss Clases</h2>
          <button
            onClick={() => setShowCreateClass(true)}
            className="bg-green-600 text-white px-4 py-2 rounded-md flex items-center gap-2"
          >
            <Plus className="w-4 h-4" /> Crear Clase
          </button>
        </div>

        {showCreateClass && (
          <div className="bg-white p-4 rounded-md shadow-md mb-6">
            <input
              type="text"
              placeholder="Nombre de la clase"
              value={newClass.title}
              onChange={(e) => setNewClass({ ...newClass, title: e.target.value })}
              className="w-full mb-2 px-3 py-2 border rounded-md"
            />
            <textarea
              placeholder="Descripción"
              value={newClass.description}
              onChange={(e) =>
                setNewClass({ ...newClass, description: e.target.value })
              }
              className="w-full mb-2 px-3 py-2 border rounded-md"
              rows="3"
            />
            <div className="flex gap-2">
              <button
                onClick={createClass}
                className="bg-blue-600 text-white px-4 py-2 rounded-md"
              >
                Crear
              </button>
              <button
                onClick={() => setShowCreateClass(false)}
                className="bg-gray-300 px-4 py-2 rounded-md"
              >
                Cancelar
              </button>
            </div>
          </div>
        )}

        {/* Lista de Clases */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {classes.map((cls) => (
            <div
              key={cls.id}
              className="bg-white p-4 rounded-md shadow hover:shadow-md transition cursor-pointer"
            >
              <div className="flex justify-between items-center mb-2">
                <h3 className="font-semibold text-lg">{cls.title}</h3>
                <button
                  onClick={() => {
                    setSelectedClass(cls);
                    setShowCreateModule(true);
                  }}
                  className="bg-blue-600 text-white px-2 py-1 rounded-md text-sm flex items-center gap-1"
                >
                  <Plus className="w-3 h-3" /> Módulo
                </button>
              </div>
              <p className="text-gray-600 text-sm mb-2">{cls.description}</p>
              <div className="text-sm text-gray-500">
                {cls.modules?.length || 0} módulos
              </div>

              {/* Mostrar lista de módulos */}
              <ul className="mt-2 space-y-1">
                {cls.modules?.map((mod) => (
                  <li
                    key={mod.id}
                    className="flex justify-between items-center px-2 py-1 bg-gray-100 rounded-md text-sm"
                  >
                    <span>{mod.title} {mod.videoUrl ? "🎬" : ""}</span>
                    <div className="flex gap-1">
                      <button
                        onClick={() => handleEditModule(mod, cls)}
                        className="bg-green-400 px-2 py-1 rounded text-xs"
                      >
                        Editar
                      </button>
                      <button
                        onClick={() => handleDeleteModule(mod, cls)}
                        className="bg-red-500 text-white px-2 py-1 rounded text-xs"
                      >
                        Eliminar
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Crear Módulo */}
        {showCreateModule && selectedClass && (
          <ModuleForm
  onCreate={createModuleOrUpdate} // función que decide si crear o actualizar
  onCancel={() => {
    setShowCreateModule(false);
    setModuleToEdit(null);
  }}
  moduleToEdit={moduleToEdit}
/>
        )}
      </div>
    </div>
  );
}
