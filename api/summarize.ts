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
        // Call OpenAI Completions API for summarization
        const completion = await openai.chat.completions.create({
            model: "gpt-4o-mini", // Or another suitable model like "gpt-4o"
            messages: [
                {"role": "system", "content": "You are a helpful assistant that summarizes meeting transcripts into key points and next steps."},
                {"role": "user", "content": `Summarize the following meeting transcript. Provide distinct sections for 'Key Points' and 'Next Steps'.\n\nTranscript: ${transcript}`}
            ],
            max_tokens: 500,
        });

        const summaryText = completion.choices[0].message.content;

        if (!summaryText) {
             return res.status(500).json({ error: 'Failed to generate summary from OpenAI' });
        }

        // Parse the summary text into key points and next steps
        // This is a basic parsing and might need refinement based on prompt exactness
        const keyPointsMatch = summaryText.match(/Key Points:\n([\s\S]*?)(?:\n\nNext Steps:|$)/);
        const nextStepsMatch = summaryText.match(/Next Steps:\n([\s\S]*)/);

        const keyPoints = keyPointsMatch ? keyPointsMatch[1].trim() : "";
        const nextSteps = nextStepsMatch ? nextStepsMatch[1].trim() : "";

        // Send the summary back
        return res.status(200).json({
            keyPoints: keyPoints,
            nextSteps: nextSteps
        });

    } catch (error) {
        console.error('Summarization error:', error);
        // More specific error handling could be added based on OpenAI API error types
        return res.status(500).json({ error: 'Failed to summarize transcript' });
    }
} 