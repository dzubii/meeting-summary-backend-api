import { VercelRequest, VercelResponse } from '@vercel/node';
import OpenAI from 'openai';

// Initialize OpenAI client with your API key
// Ensure process.env.OPENAI_API_KEY is set in your Vercel environment variables
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export default async function (request: VercelRequest, response: VercelResponse) {
  if (request.method === 'POST') {
    try {
      const { transcript } = request.body;

      if (!transcript) {
        return response.status(400).json({ error: 'Transcript is required in the request body.' });
      }

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
        model: 'gpt-3.5-turbo', // Using a cost-effective model
        max_tokens: 20, // Set a low max_tokens to encourage brevity
        temperature: 0.7, // Adjust temperature for creativity (0.7 is a good balance)
      });

      const title = chatCompletion.choices[0].message.content?.trim() || 'Untitled Meeting';

      return response.status(200).json({ title });
    } catch (error) {
      console.error('Error generating title summary:', error);
      return response.status(500).json({ error: 'Failed to generate title summary.' });
    }
  } else {
    return response.status(405).json({ error: 'Method Not Allowed' });
  }
}