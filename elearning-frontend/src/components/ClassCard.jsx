import React from "react";

export default function ClassCard({ cls, onSelect }) {
  return (
    <div
      className="bg-white p-4 rounded-md shadow hover:shadow-md transition cursor-pointer"
      onClick={() => onSelect(cls)}
    >
      
      <h3 className="font-semibold text-lg">{cls.title}</h3>
      <p className="text-gray-600 text-sm">{cls.description}</p>
      <div className="text-sm text-gray-500 mt-2">
        {cls.modules?.length || 0} módulos
      </div>
    </div>
  );
}
