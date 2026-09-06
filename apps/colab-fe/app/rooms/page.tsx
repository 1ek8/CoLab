"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import axios from "axios";
import { BACKEND_URL } from "@/config";

export default function RoomsPage() {
  const router = useRouter();
  const [roomName, setRoomName] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [authenticated, setAuthenticated] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (!token) {
      router.push("/signin");
    } else {
      setAuthenticated(true);
    }
  }, [router]);

  const handleCreateRoom = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    const token = localStorage.getItem("token");
    if (!token) {
      router.push("/signin");
      return;
    }

    try {
      const res = await axios.post(
        `${BACKEND_URL}/room`,
        { name: roomName },
        { headers: { Authorization: token } }
      );
      router.push(`/canvas/${res.data.roomId}`);
    } catch (err: any) {
      const message =
        err.response?.data?.message || "Failed to create room. Try again.";
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  if (!authenticated) {
    return null;
  }

  return (
    <div className="w-screen h-screen flex justify-center items-center bg-gray-100">
      <form
        onSubmit={handleCreateRoom}
        className="p-6 m-4 bg-white rounded-xl shadow-md border border-gray-300 max-w-sm w-full"
      >
        <h2 className="text-xl font-bold text-center mb-4 text-gray-800">
          Create a Room
        </h2>

        <input
          className="w-full mb-4 px-4 py-2 border border-gray-300 rounded-md placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          type="text"
          placeholder="Room name (3-20 characters)"
          value={roomName}
          onChange={(e) => setRoomName(e.target.value)}
          required
          minLength={3}
          maxLength={20}
        />

        {error && (
          <p className="text-red-500 text-sm mb-4 text-center">{error}</p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-indigo-600 hover:bg-indigo-700 text-white py-2 rounded-md font-semibold transition disabled:opacity-50"
        >
          {loading ? "Creating..." : "Create Room"}
        </button>

        <button
          type="button"
          onClick={() => {
            localStorage.removeItem("token");
            router.push("/signin");
          }}
          className="w-full mt-3 text-gray-500 hover:text-gray-700 text-sm py-2 transition"
        >
          Sign out
        </button>
      </form>
    </div>
  );
}
