const API_URL = "http://localhost:4000"

const callAPI = async (endpoint, method = "GET", token = null, body = null, isFormData = false) => {
  const headers = {}

  if (!isFormData) headers["Content-Type"] = "application/json"
  if (token) headers["Authorization"] = `Bearer ${token}`

  const res = await fetch(`${API_URL}${endpoint}`, {
    method,
    headers,
    body: isFormData ? body : body ? JSON.stringify(body) : null
  })

  if (!res.ok) {
    const errorData = await res.json().catch(() => ({}))
    throw new Error(errorData.message || "Error en petición al servidor")
  }

  return res
}

export const api = {

  // auth
  login: (email, password) =>
    callAPI("/auth/login", "POST", null, { email, password }).then(r => r.json()),

  register: (data) =>
    callAPI("/auth/register", "POST", null, data).then(r => r.json()),

  // classes
  getClasses: (token) =>
    callAPI("/classes", "GET", token).then(r => r.json()),

  createClass: (token, cls) =>
    callAPI("/classes", "POST", token, cls).then(r => r.json()),

  createModule: (token, classId, moduleData) =>
    callAPI(`/classes/${classId}/modules`, "POST", token, moduleData).then(r => r.json()),

  uploadVideo: (token, moduleId, file) => {
    const fd = new FormData()
    fd.append("video", file)
    return callAPI(`/modules/${moduleId}/video`, "POST", token, fd, true)
  },

  getVideo: (token, moduleId) =>
    callAPI(`/modules/${moduleId}/video`, "GET", token).then(r => r.blob()),
}
