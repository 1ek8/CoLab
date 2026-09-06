import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { JWT_SECRET } from "@repo/backend-common/config";

export const middleware = (req: Request, res: Response, next: NextFunction) => {
    const token = req.headers["authorization"] ?? "";

    if (!token) {
        res.status(403).json({ message: "Unauthorized" });
        return;
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);

        if (typeof decoded === "string" || !decoded || !(decoded as jwt.JwtPayload).userId) {
            res.status(403).json({ message: "Unauthorized" });
            return;
        }

        //@ts-ignore
        req.userId = (decoded as jwt.JwtPayload).userId;
        next();
    } catch {
        res.status(403).json({ message: "Unauthorized" });
    }
};