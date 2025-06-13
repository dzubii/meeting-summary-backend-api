/// <reference types="node" />
import { VercelRequest, VercelResponse } from '@vercel/node';

export default async function handler(req: VercelRequest, res: VercelResponse) {
    console.log('hello.ts function invoked');

    if (req.method === 'GET') {
        return res.status(200).json({ message: 'Hello from /api/hello!' });
    } else {
        return res.status(405).json({ error: 'Method Not Allowed' });
    }
} 