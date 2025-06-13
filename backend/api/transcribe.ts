/// <reference types="node" />
import { VercelRequest, VercelResponse } from '@vercel/node';
import OpenAI from 'openai';
import formidable from 'formidable';
import fs from 'fs';

// Configure formidable to use the serverless function's temporary directory
const form = formidable({
    uploadDir: '/tmp',
    keepExtensions: true
});

export const config = {
    api: {
        bodyParser: false, // Disable Vercel's body parser to use formidable
    },
};

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

    // Parse multipart form data
    try {
        const { files } = await new Promise<{ fields: formidable.Fields, files: formidable.Files }>((resolve, reject) => {
            form.parse(req, (err, fields, files) => {
                if (err) reject(err);
                resolve({ fields, files });
            });
        });

        const audioFile = files.audio ? (Array.isArray(files.audio) ? files.audio[0] : files.audio) : null;

        if (!audioFile) {
            return res.status(400).json({ error: 'No audio file provided' });
        }

        // Ensure OPENAI_API_KEY is set
        if (!process.env.OPENAI_API_KEY) {
             // Clean up the temporary file before returning error
             fs.unlink(audioFile.filepath, (err) => {
                 if (err) console.error('Error deleting temp file:', err);
             });
            return res.status(500).json({ error: 'Server configuration error: OPENAI_API_KEY not set' });
        }

        // Initialize OpenAI client
        const openai = new OpenAI();

        // Read the audio file content
        const fileContent = fs.createReadStream(audioFile.filepath);

        // Call OpenAI Whisper API for transcription
        const transcription = await openai.audio.transcriptions.create({
            file: fileContent,
            model: "whisper-1",
        });

        // Clean up the temporary file
         fs.unlink(audioFile.filepath, (err) => {
             if (err) console.error('Error deleting temp file:', err);
         });

        // Send the transcription back
        return res.status(200).json({ text: transcription.text });

    } catch (error) {
        console.error('Transcription error:', error);

        // Attempt to clean up temp file if it exists and we know its path
        // Note: This is a best effort, might not always have the path in catch
        // if the error happened during parsing before filepath was determined.
         if (error instanceof Error && 'filepath' in error && typeof error.filepath === 'string') {
              fs.unlink(error.filepath, (err) => {
                  if (err) console.error('Error deleting temp file in catch:', err);
              });
         }

        return res.status(500).json({ error: 'Failed to transcribe audio' });
    }
} 