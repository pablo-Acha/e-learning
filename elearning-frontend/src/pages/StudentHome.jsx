import { useEffect, useState } from "react"; 
import { BookOpen } from "lucide-react";
import ClassCard from "../components/ClassCard";
import ModuleCard from "../components/ModuleCard";
import { useAuthStore } from "../store/useAuthStore";

const API_URL = "http://3.19.223.47/api";

export default function StudentHome() {
  const { token, userId } = useAuthStore();
  const [classes, setClasses] = useState([]);
  const [allClasses, setAllClasses] = useState([]);
  const [selectedClass, setSelectedClass] = useState(null);
  const [videoUrl, setVideoUrl] = useState(null);
  const [loadingVideo, setLoadingVideo] = useState(false);
  const [showAllClasses, setShowAllClasses] = useState(false);

  useEffect(() => {
    fetchClasses();
  }, []);

  const fetchClasses = async () => {
    try {
      const res = await fetch(`${API_URL}/students/classes`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      setClasses(data);
    } catch (err) {
      console.error(err);
    }
  };

  const fetchAllClasses = async () => {
    try {
      const res = await fetch(`${API_URL}/classes`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      setAllClasses(data);
    } catch (err) {
      console.error(err);
    }
  };

  const watchVideo = async (module) => {
    if (!module.videoUrl) return;

    try {
      setLoadingVideo(true);
      const res = await fetch(`${API_URL}/modules/${module.id}/video`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error("Error obteniendo URL del video");
      const data = await res.json();
      setVideoUrl(data.signedUrl);
    } catch (err) {
      console.error(err);
    } finally {
      setLoadingVideo(false);
    }
  };

  const enrollInClass = async (classId) => {
    try {
      const res = await fetch(`${API_URL}/enrollments`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ studentId: userId, classId }),
      });

      if (!res.ok) throw new Error("Error al inscribirse");
      alert("¡Inscripción exitosa!");
      setShowAllClasses(false);
      fetchClasses(); // refresca las clases inscritas
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="p-6 max-w-6xl mx-auto mt-6">
      {!selectedClass && !showAllClasses && (
        <>
          <button
            onClick={() => {
              setShowAllClasses(true);
              fetchAllClasses();
            }}
            className="mb-4 bg-blue-600 text-white px-4 py-2 rounded-md"
          >
            Ver todas las clases
          </button>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {classes.map((cls) => (
              <ClassCard
                key={cls.id}
                cls={cls}
                onSelect={setSelectedClass}
              />
            ))}
          </div>
        </>
      )}

      {showAllClasses && (
        <div>
          <button
            onClick={() => setShowAllClasses(false)}
            className="mb-4 text-blue-600 hover:underline"
          >
            ← Volver a mis clases
          </button>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {allClasses.map((cls) => (
              <div key={cls.id} className="bg-white p-4 rounded-md shadow">
                <h3 className="font-semibold text-lg">{cls.title}</h3>
                <p className="text-gray-600 mb-2">{cls.description}</p>
                <p className="text-gray-500 mb-2">Precio: $0</p>
                <button
                  onClick={() => enrollInClass(cls.id)}
                  className="bg-green-600 text-white px-3 py-1 rounded-md"
                >
                  Inscribirse
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {selectedClass && (
        <div>
          <button
            onClick={() => {
              setSelectedClass(null);
              setVideoUrl(null);
            }}
            className="mb-4 text-blue-600 hover:underline"
          >
            ← Volver a mis clases
          </button>

          <div className="bg-white p-4 rounded-md shadow mb-4">
            <h3 className="text-2xl font-bold mb-2">{selectedClass.title}</h3>
            <p className="text-gray-600 mb-4">{selectedClass.description}</p>

            {loadingVideo && <p className="mb-4 text-gray-500">Cargando video...</p>}

            {videoUrl && (
              <div className="mb-4">
                <video
                  src={videoUrl}
                  controls
                  className="w-full rounded-md"
                  style={{ maxHeight: "400px" }}
                />
              </div>
            )}

            <div className="space-y-3">
              {selectedClass.modules?.map((mod) => (
                <ModuleCard
                  key={mod.id}
                  module={mod}
                  onWatch={() => watchVideo(mod)}
                />
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
