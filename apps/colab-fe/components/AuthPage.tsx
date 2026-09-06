"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import axios from "axios";
import { BACKEND_URL } from "@/config";

export function AuthPage({ isSignIn }: { isSignIn: boolean }) {
  const router = useRouter();
  const [name, setName] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (isSignIn) {
        const res = await axios.post(`${BACKEND_URL}/signin`, {
          username,
          password,
        });
        localStorage.setItem("token", res.data.token);
        router.push("/rooms");
      } else {
        await axios.post(`${BACKEND_URL}/signup`, {
          name,
          username,
          password,
        });
        const res = await axios.post(`${BACKEND_URL}/signin`, {
          username,
          password,
        });
        localStorage.setItem("token", res.data.token);
        router.push("/rooms");
      }
    } catch (err: any) {
      const message =
        err.response?.data?.message || "Something went wrong. Try again.";
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-screen h-screen flex justify-center items-center bg-gray-100">
      <form
        onSubmit={handleSubmit}
        className="p-6 m-4 bg-white rounded-xl shadow-md border border-gray-300 max-w-sm w-full"
      >
        <h2 className="text-xl font-bold text-center mb-4 text-gray-800">
          {isSignIn ? "Sign In" : "Sign Up"}
        </h2>

        {!isSignIn && (
          <input
            className="w-full mb-4 px-4 py-2 border border-gray-300 rounded-md placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            type="text"
            placeholder="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />
        )}

        <input
          className="w-full mb-4 px-4 py-2 border border-gray-300 rounded-md placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          type="text"
          placeholder="Username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          required
          minLength={3}
        />

        <input
          className="w-full mb-6 px-4 py-2 border border-gray-300 rounded-md placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          minLength={3}
        />

        {error && (
          <p className="text-red-500 text-sm mb-4 text-center">{error}</p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-indigo-600 hover:bg-indigo-700 text-white py-2 rounded-md font-semibold transition disabled:opacity-50"
        >
          {loading
            ? "Please wait..."
            : isSignIn
              ? "Sign In"
              : "Sign Up"}
        </button>

        <p className="text-sm text-center mt-4 text-gray-600">
          {isSignIn ? (
            <>
              Don&apos;t have an account?{" "}
              <a href="/signup" className="text-indigo-600 hover:underline">
                Sign up
              </a>
            </>
          ) : (
            <>
              Already have an account?{" "}
              <a href="/signin" className="text-indigo-600 hover:underline">
                Sign in
              </a>
            </>
          )}
        </p>
      </form>
    </div>
  );
}
