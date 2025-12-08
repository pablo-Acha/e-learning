import { useEffect, useState } from "react";
import { useAuthStore } from "../store/useAuthStore";

const API_URL = "http://3.19.223.47/api";

export default function AdminHome() {
  const { token } = useAuthStore();

  const [classes, setClasses] = useState([]);
  const [students, setStudents] = useState([]);
  const [teachers, setTeachers] = useState([]);
  const [selectedClass, setSelectedClass] = useState(null);
  const [classStudents, setClassStudents] = useState([]);

  useEffect(() => {
    fetchClasses();
    fetchStudents();
    fetchTeachers();
  }, []);

  const fetchClasses = async () => {
    try {
      const res = await fetch(`${API_URL}/admin/classes-dashboard`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      setClasses(data);
    } catch (err) {
      console.error(err);
    }
  };

  const fetchStudents = async () => {
    try {
      const res = await fetch(`${API_URL}/admin/students`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      setStudents(data);
    } catch (err) {
      console.error(err);
    }
  };

  const fetchTeachers = async () => {
    try {
      const res = await fetch(`${API_URL}/admin/teachers`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      setTeachers(data);
    } catch (err) {
      console.error(err);
    }
  };

  const viewClassStudents = async (cls) => {
    try {
      const res = await fetch(`${API_URL}/admin/class/${cls.id}/students`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      setSelectedClass(cls);
      setClassStudents(data);
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Navbar fijo */}
      <nav className="fixed top-0 left-0 right-0 bg-white shadow p-4 z-10 flex justify-between items-center">
        <h1 className="text-xl font-bold">Admin Dashboard</h1>
      </nav>

      <div className="pt-20 max-w-6xl mx-auto p-6">
        {!selectedClass ? (
          <>
            <section className="mb-8">
              <h2 className="text-2xl font-bold mb-4">Clases</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {classes.map((cls) => (
                  <div
                    key={cls.id}
                    className="bg-white p-4 rounded-md shadow hover:shadow-md cursor-pointer"
                    onClick={() => viewClassStudents(cls)}
                  >
                    <h3 className="font-semibold text-lg">{cls.title}</h3>
                    <p className="text-gray-600 mb-2">{cls.description}</p>
                    <div className="text-sm text-gray-500">
                      {cls._count.modules} módulos | {cls._count.enrollments} estudiantes
                    </div>
                    <div className="text-sm text-gray-700 mt-1">
                      Docente: {cls.teacher.name}
                    </div>
                  </div>
                ))}
              </div>
            </section>

            <section className="mb-8">
              <h2 className="text-2xl font-bold mb-4">Estudiantes</h2>
              <ul className="bg-white rounded-md shadow divide-y divide-gray-200">
                {students.map((s) => (
                  <li key={s.id} className="p-3">{s.name} - {s.email}</li>
                ))}
              </ul>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Docentes</h2>
              <ul className="bg-white rounded-md shadow divide-y divide-gray-200">
                {teachers.map((t) => (
                  <li key={t.id} className="p-3">{t.name} - {t.email}</li>
                ))}
              </ul>
            </section>
          </>
        ) : (
          <div>
            <button
              onClick={() => {
                setSelectedClass(null);
                setClassStudents([]);
              }}
              className="mb-4 text-blue-600 hover:underline"
            >
              ← Volver a clases
            </button>

            <h2 className="text-2xl font-bold mb-4">Estudiantes de {selectedClass.title}</h2>
            <ul className="bg-white rounded-md shadow divide-y divide-gray-200">
              {classStudents.map((s) => (
                <li key={s.id} className="p-3">{s.name} - {s.email}</li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </div>
  );
}
