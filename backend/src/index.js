require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const Redis = require('redis');
const multer = require('multer');
const { OpenAI } = require('openai');
const winston = require('winston');

// Initialize Express app
const app = express();

// Configure logging
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' })
    ]
});

if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple()
    }));
}

// Initialize Redis client
const redisClient = Redis.createClient({
    url: process.env.REDIS_URL
});

redisClient.on('error', (err) => logger.error('Redis Client Error:', err));
redisClient.connect();

// Initialize OpenAI client
const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY
});

// Configure multer for file uploads
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 25 * 1024 * 1024, // 25MB limit
    }
});

// Security middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
    store: new RedisStore({
        sendCommand: (...args) => redisClient.sendCommand(args),
    }),
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000, // 15 minutes
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
    message: 'Too many requests from this IP, please try again later.'
});

app.use(limiter);

// API key validation middleware
const validateApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey || apiKey !== process.env.API_KEY_SECRET) {
        logger.warn('Invalid API key attempt', { ip: req.ip });
        return res.status(401).json({ error: 'Invalid API key' });
    }
    next();
};

// Routes
app.post('/api/transcribe', validateApiKey, upload.single('audio'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No audio file provided' });
        }

        const transcription = await openai.audio.transcriptions.create({
            file: req.file.buffer,
            model: "whisper-1"
        });

        logger.info('Transcription completed', { 
            fileSize: req.file.size,
            duration: req.body.duration
        });

        res.json({ text: transcription.text });
    } catch (error) {
        logger.error('Transcription error:', error);
        res.status(500).json({ error: 'Failed to transcribe audio' });
    }
});

app.post('/api/summarize', validateApiKey, async (req, res) => {
    try {
        const { transcript } = req.body;
        if (!transcript) {
            return res.status(400).json({ error: 'No transcript provided' });
        }

        // Split transcript into chunks
        const chunks = splitIntoChunks(transcript);
        
        // Summarize each chunk
        const chunkSummaries = await Promise.all(
            chunks.map(chunk => summarizeChunk(chunk))
        );

        // Create final summary
        const finalSummary = await createFinalSummary(chunkSummaries.join('\n\n'));

        logger.info('Summary completed', { 
            transcriptLength: transcript.length,
            chunks: chunks.length
        });

        res.json(finalSummary);
    } catch (error) {
        logger.error('Summarization error:', error);
        res.status(500).json({ error: 'Failed to summarize transcript' });
    }
});

// Helper functions
function splitIntoChunks(text) {
    const sentences = text.split('. ');
    const chunks = [];
    let currentChunk = '';

    for (const sentence of sentences) {
        if (currentChunk.length + sentence.length > 2500) {
            chunks.push(currentChunk);
            currentChunk = sentence;
        } else {
            currentChunk += (currentChunk ? '. ' : '') + sentence;
        }
    }

    if (currentChunk) {
        chunks.push(currentChunk);
    }

    return chunks;
}

async function summarizeChunk(chunk) {
    const response = await openai.chat.completions.create({
        model: "gpt-3.5-turbo",
        messages: [
            {
                role: "system",
                content: "You are a helpful assistant that summarizes meeting transcripts."
            },
            {
                role: "user",
                content: `Summarize the following meeting transcript section, focusing on key points and next steps:\n\n${chunk}`
            }
        ],
        temperature: 0.7
    });

    return response.choices[0].message.content;
}

async function createFinalSummary(combinedSummary) {
    const response = await openai.chat.completions.create({
        model: "gpt-4",
        messages: [
            {
                role: "system",
                content: "You are a helpful assistant that summarizes meeting transcripts."
            },
            {
                role: "user",
                content: `Summarize the following meeting transcript into two parts:
                1. Key Points: List the main points discussed
                2. Next Steps: List any action items or next steps mentioned
                
                If no next steps are mentioned, omit that section. Focus only on actionable and insightful content.
                
                Transcript:
                ${combinedSummary}`
            }
        ],
        temperature: 0.7
    });

    const summary = response.choices[0].message.content;
    const components = summary.split('Next Steps:');
    
    return {
        keyPoints: components[0].replace('Key Points:', '').trim(),
        nextSteps: components.length > 1 ? components[1].trim() : ''
    };
}

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    logger.info(`Server running on port ${PORT}`);
}); 