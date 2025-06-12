/// <reference types="node" />
import { VercelRequest, VercelResponse } from '@vercel/node';
import OpenAI from 'openai';

// Disable body parsing, handle raw body
export const config = {
    api: {
        bodyParser: true,
    },
};

// Export the handler function
export default async function handler(req: VercelRequest, res: VercelResponse) {
    console.log('generate-title.ts: Request received');
    console.log('generate-title.ts: Request method:', req.method);
    console.log('generate-title.ts: Request headers:', JSON.stringify(req.headers, null, 2));
    console.log('generate-title.ts: Request body:', JSON.stringify(req.body, null, 2));

    // Add CORS headers
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
    res.setHeader(
        'Access-Control-Allow-Headers',
        'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, x-api-key'
    );

    // Handle preflight request
    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    // Validate request method
    if (req.method !== 'POST') {
        console.log('generate-title.ts: Invalid method - returning 405');
        return res.status(405).json({ error: 'Method Not Allowed' });
    }

    // Validate API Key Secret
    const apiKeySecret = req.headers['x-api-key'];
    console.log('generate-title.ts: API Key Secret present:', !!apiKeySecret);
    if (apiKeySecret !== process.env.API_KEY_SECRET) {
        console.log('generate-title.ts: Invalid API Key - returning 401');
        return res.status(401).json({ error: 'Invalid API Key' });
    }

    // Ensure OPENAI_API_KEY is set
    console.log('generate-title.ts: OPENAI_API_KEY present:', !!process.env.OPENAI_API_KEY);
    if (!process.env.OPENAI_API_KEY) {
        console.log('generate-title.ts: Missing OPENAI_API_KEY - returning 500');
        return res.status(500).json({ error: 'Server configuration error: OPENAI_API_KEY not set' });
    }

    // Parse request body
    let transcript: string;
    try {
        const body = req.body;
        console.log('generate-title.ts: Request body type:', typeof body);
        console.log('generate-title.ts: Request body keys:', Object.keys(body || {}));
        
        if (!body || typeof body.transcript !== 'string') {
            console.log('generate-title.ts: Invalid request body - returning 400');
            return res.status(400).json({ error: 'Invalid request body: missing transcript' });
        }
        transcript = body.transcript;
        console.log('generate-title.ts: Transcript length:', transcript.length);
    } catch (error) {
        console.error('generate-title.ts: Error parsing request body:', error);
        return res.status(400).json({ error: 'Invalid request body' });
    }

    // Initialize OpenAI client
    const openai = new OpenAI();

    try {
        console.log('generate-title.ts: Calling OpenAI API');
        // Call OpenAI's chat completion API to generate a short title summary
        const chatCompletion = await openai.chat.completions.create({
            messages: [
                {
                    role: 'system',
                    content: 'You are a helpful assistant that summarizes meeting transcripts into short, concise titles (less than 10 words).',
                },
                {
                    role: 'user',
                    content: `Generate a title for the following meeting transcript, less than 10 words: "${transcript}"`,
                },
            ],
            model: 'gpt-3.5-turbo',
            max_tokens: 20,
            temperature: 0.7,
        });

        const title = chatCompletion.choices[0].message.content?.trim() || 'Untitled Meeting';
        console.log('generate-title.ts: Generated title:', title);

        return res.status(200).json({ title });
    } catch (error) {
        console.error('generate-title.ts: Error generating title summary:', error);
        return res.status(500).json({ error: 'Failed to generate title summary.' });
    }
}