import express from "express";
import jwt from "jsonwebtoken";
import bcrypt from "bcrypt";
import { JWT_SECRET } from "@repo/backend-common/config";
import { middleware } from "./middleware";
import { CreateUserSchema, CreateRoomSchema, SigninSchema } from "@repo/common/types";
import { prismaClient } from "@repo/db/client";
import cors from "cors";

const app = express();
app.use(express.json());

const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",")
  : ["http://localhost:3000"];

app.use(
  cors({
    origin: ALLOWED_ORIGINS,
    credentials: true,
  })
);

const PORT = process.env.PORT || 3001;
const SALT_ROUNDS = 10;

app.post("/signup", async (req, res) => {
  const parsedData = CreateUserSchema.safeParse(req.body);
  if (!parsedData.success) {
    res.status(400).json({
      message: "Incorrect inputs",
    });
    return;
  }

  try {
    const hashedPassword = await bcrypt.hash(parsedData.data.password, SALT_ROUNDS);
    const user = await prismaClient.user.create({
      data: {
        username: parsedData.data.username,
        password: hashedPassword,
        name: parsedData.data.name,
      },
    });

    res.json({
      userId: user.id,
    });
  } catch (error) {
    res.status(411).json({
      message: "User already exists or database error",
    });
  }
});

app.post("/signin", async (req, res) => {
  const parsedData = SigninSchema.safeParse(req.body);
  if (!parsedData.success) {
    res.status(400).json({
      message: "Incorrect inputs",
    });
    return;
  }

  try {
    const user = await prismaClient.user.findFirst({
      where: {
        username: parsedData.data.username,
      },
    });

    if (!user) {
      res.status(403).json({
        message: "Invalid credentials",
      });
      return;
    }

    const validPassword = await bcrypt.compare(parsedData.data.password, user.password);
    if (!validPassword) {
      res.status(403).json({
        message: "Invalid credentials",
      });
      return;
    }

    const token = jwt.sign(
      { userId: user.id },
      JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.json({
      token,
    });
  } catch (error) {
    res.status(500).json({
      message: "Internal server error",
    });
  }
});

app.post("/room", middleware, async (req, res) => {
  const parsedData = CreateRoomSchema.safeParse(req.body);
  if (!parsedData.success) {
    res.status(400).json({
      message: "Incorrect inputs",
    });
    return;
  }
  //@ts-ignore
  const userId = req.userId;

  try {
    const room = await prismaClient.room.create({
      data: {
        slug: parsedData.data.name,
        adminId: userId,
      },
    });

    res.json({
      roomId: room.id,
    });
  } catch (error) {
    res.status(411).json({
      message: "Room not created",
    });
  }
});

app.get("/chats/:roomId", async (req, res) => {
  try {
    const roomId = Number(req.params.roomId);
    const messages = await prismaClient.chat.findMany({
      where: {
        roomId,
      },
      orderBy: {
        id: "desc",
      },
      take: 100,
    });
    res.json({ messages });
  } catch (error) {
    res.json({ messages: [] });
  }
});

app.get("/room/:slug", async (req, res) => {
  const slug = req.params.slug;
  const room = await prismaClient.room.findFirst({
    where: {
      slug,
    },
  });

  res.json({
    room,
  });
});

app.listen(PORT, () => {
  console.log(`HTTP backend listening on port ${PORT}`);
});
