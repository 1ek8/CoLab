import { WebSocket, WebSocketServer } from "ws";
import jwt, { JwtPayload } from "jsonwebtoken";
import { JWT_SECRET } from "@repo/backend-common/config";
import { prismaClient } from "@repo/db/client";

const wss = new WebSocketServer({port: Number(process.env.PORT) || 8080});

interface User {
    ws: WebSocket,
    rooms: string[],
    userId: string
}

const users: User[] = []

function authUser(token: string) : string | null {
    try {
        const decoded = jwt.verify(token, JWT_SECRET);

        if(typeof decoded == "string"){
            return null;
        }
    
    
        if(!decoded || !(decoded as JwtPayload).userId){
            return null;
        }
    
        return decoded.userId;
    } catch (error) {
        return null;
    }
} 

wss.on('connection', function connection(ws, request){
    
    const url = request.url;
    if(!url)
        return;

    const queryParams = new URLSearchParams(url.split('?')[1]);
    const token = queryParams.get('token') || '';

    const userId = authUser(token)
    
    if(userId == null){
        ws.close();
        return;
    }
    

    users.push({
        userId,
        rooms:[],
        ws
    })

    console.log("Pushed the following user:");
    console.log(userId)

    ws.on('message', async function message(data: unknown){
//      this if block always gets true.
        // if(typeof data !== "string"){
        //     console.log("datatype is not string")
        //     return;
        // }

        // type string is not assignable to RawData
        // if (typeof data !== 'string') {
        //     try {
        //         data = data.toString(); // handles Buffer
        //     } catch {
        //         return; // not a string and can't convert? skip
        //     }
        // }
        
        //doing data as string seems to be enough
        const parsedData = JSON.parse(data as string);
        console.log("\nParsed the data")
        
        if (parsedData.type === "join_room") {
            console.log("\nMessage type is join_room")
            const user = users.find(x => x.ws === ws)
            console.log("\found the user with given websocket")
            if(!user){
                console.log('no user available in rooms[] with given ws')
                return;
            }
            
            user.rooms.push(parsedData.roomId)
            console.log(`\n Pushed roomId ${parsedData.roomId} for userId: ${user.userId}`)
        }

        if (parsedData.type === "leave_room") {
            const user = users.find(x => x.ws === ws)
            if(!user){
                console.log('no user available in rooms[] with given ws')
                return;
            }

            console.log(`\n Deleting roomId ${parsedData.roomId} for userId: ${user.userId}`)
            user.rooms = user.rooms.filter(x => x === parsedData.roomId)
        }

        if (parsedData.type === "chat") {
            const roomId = parsedData.roomId;
            const message = parsedData.message;
            

            await prismaClient.chat.create({
                data:{
                    roomId,
                    message,
                    userId
                }
            })

            console.log(`Stored the data ${roomId}, ${message} and ${userId}`)
            users.forEach(user => {
                if(user.rooms.includes(roomId)){
                    user.ws.send(JSON.stringify({
                        type: "chat",
                        message,
                        roomId,
                        userId
                    }))
                }
            })

            
            
        }
    })
})