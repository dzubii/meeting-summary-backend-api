/// <reference types="node" />
import { VercelRequest, VercelResponse } from '@vercel/node';
import OpenAI from 'openai';

export default async function handler(req: VercelRequest, res: VercelResponse) {
    console.log('generate-title function invoked');

    // 1. Validate Request Method
    // Only allow POST requests, reject others with 405 Method Not Allowed.
    if (req.method !== 'POST') {
        res.setHeader('Allow', 'POST'); // It's good practice to include the Allow header
        return res.status(405).json({ error: 'Method Not Allowed' });
    }

    // 2. Validate Custom API Key Secret for authorization
    const apiKeySecret = req.headers['x-api-key'];
    if (apiKeySecret !== process.env.API_KEY_SECRET) {
        return res.status(401).json({ error: 'Unauthorized: Invalid API Key' });
    }

    // 3. Ensure OpenAI API Key is configured on the server
    if (!process.env.OPENAI_API_KEY) {
        console.error('Server configuration error: OPENAI_API_KEY not set');
        return res.status(500).json({ error: 'Server configuration error. The developer needs to set the OPENAI_API_KEY environment variable.' });
    }

    // 4. Parse and Validate Request Body
    let transcript: string;
    try {
        // Vercel automatically parses JSON bodies, so req.body should be an object.
        const body = req.body;
        if (!body || typeof body.transcript !== 'string' || body.transcript.trim() === '') {
            return res.status(400).json({ error: 'Invalid request: "transcript" must be a non-empty string in the request body.' });
        }
        transcript = body.transcript;
    } catch (error) {
        console.error('Error parsing request body:', error);
        return res.status(400).json({ error: 'Invalid JSON in request body.' });
    }

    // 5. Initialize OpenAI Client
    // The client automatically picks up the OPENAI_API_KEY from process.env.
    const openai = new OpenAI();

    // 6. Call OpenAI API and Handle Response
    try {
        const chatCompletion = await openai.chat.completions.create({
            messages: [
                {
                    role: 'system',
                    content: 'You are an expert summarizer. Your task is to create a concise, informative title for a meeting transcript. The title should be under 10 words.',
                },
                {
                    role: 'user',
                    content: `Generate a title (less than 10 words) for the following transcript:\n\n"${transcript}"`,
                },
            ],
            model: 'gpt-3.5-turbo',
            max_tokens: 25,   // A bit more buffer for the title
            temperature: 0.7,
            n: 1,             // We only need one title choice
        });

        // Extract the generated title from the API response
        const title = chatCompletion.choices[0]?.message?.content?.trim();

        if (!title) {
            console.error('OpenAI response did not contain message content.');
            return res.status(500).json({ error: 'Failed to generate title from AI response.' });
        }

        // 7. Send Successful Response
        // On success, return a 200 OK with the generated title.
        return res.status(200).json({ title });

    } catch (error: any) {
        console.error('Error calling OpenAI API:', error);
        
        // Provide more specific error feedback based on the OpenAI client's error structure
        if (error instanceof OpenAI.APIError) {
             return res.status(error.status || 500).json({ error: `OpenAI API Error: ${error.message}` });
        } else {
             return res.status(500).json({ error: 'An unexpected error occurred while processing your request.' });
        }
    }
}
