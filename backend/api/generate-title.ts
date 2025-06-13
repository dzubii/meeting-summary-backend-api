/// <reference types="node" />
import { VercelRequest, VercelResponse } from '@vercel/node';
import OpenAI from 'openai';

export default async function handler(req: VercelRequest, res: VercelResponse) {
    // Validate request method
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method Not Allowed' });
    }

    // Validate API Key Secret
    const apiKeySecret = req.headers['x-api-key'];
    if (apiKeySecret !== process.env.API_KEY_SECRET) {
        return res.status(401).json({ error: 'Invalid API Key' });
    }

    // Ensure OPENAI_API_KEY is set
    if (!process.env.OPENAI_API_KEY) {
        return res.status(500).json({ error: 'Server configuration error: OPENAI_API_KEY not set' });
    }

    // Parse request body
    let transcript: string;
    try {
        const body = req.body;
        if (!body || typeof body.transcript !== 'string') {
            return res.status(400).json({ error: 'Invalid request body: missing transcript' });
        }
        transcript = body.transcript;
    } catch (error) {
        console.error('Error parsing request body:', error);
        return res.status(400).json({ error: 'Invalid request body' });
    }

    // Initialize OpenAI client
    const openai = new OpenAI();

    try {
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

        return res.status(200).json({ title });
    } catch (error) {
        console.error('Error generating title summary:', error);
        return res.status(500).json({ error: 'Failed to generate title summary.' });
    }
}