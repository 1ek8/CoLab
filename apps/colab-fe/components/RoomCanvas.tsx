"use client"

import { WS_URL } from "@/config";
import { useEffect, useState } from "react";
import { Canvas } from "./Canvas";

export function RoomCanvas ({roomId}: {roomId:string}) {
    const [socket, setSocket] = useState<WebSocket | null>(null)
    const [error, setError] = useState<string | null>(null)
        
    useEffect(() => {
        const token = localStorage.getItem("token");
        if (!token) {
            setError("Please sign in to join this room.");
            return;
        }

        const ws = new WebSocket(`${WS_URL}?token=${token}`)

        ws.onopen = () => {
            setSocket(ws);
            ws.send(JSON.stringify({
                type: "join_room",
                roomId: Number(roomId)
            }))
        }

        ws.onclose = () => {
            setSocket(null);
        }

        ws.onerror = () => {
            setError("Failed to connect to the server.");
        }

        return ()=>{
            ws.close()
        }
    }, [roomId])

    if (error) {
        return <div className="w-screen h-screen flex items-center justify-center bg-gray-100">
            <a href="/signin" className="text-indigo-600 hover:underline">{error}</a>
        </div>
    }

    if(!socket){
        return <div>
            Connecting to server...
        </div>
    }

    return <div>
        <Canvas roomId = {roomId} socket = {socket}/>
    </div>
}