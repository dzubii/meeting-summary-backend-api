require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
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

// Initialize OpenAI client
const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY
});

// Configure multer for file uploads
const upload = multer({
    limits: {
        fileSize: 25 * 1024 * 1024 // 25MB limit
    }
});

// Security middleware
app.use(helmet());
app.use(cors({
    origin: process.env.NODE_ENV === 'production' 
        ? ['https://your-app-domain.com'] // Replace with your app's domain
        : '*'
}));
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
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
        logger.error('Transcription error', { error: error.message });
        res.status(500).json({ error: 'Failed to transcribe audio' });
    }
});

app.post('/api/summarize', validateApiKey, async (req, res) => {
    try {
        const { transcript } = req.body;
        if (!transcript) {
            return res.status(400).json({ error: 'No transcript provided' });
        }

        const completion = await openai.chat.completions.create({
            model: "gpt-4",
            messages: [
                {
                    role: "system",
                    content: "You are a helpful assistant that summarizes meeting transcripts. Provide key points and next steps."
                },
                {
                    role: "user",
                    content: transcript
                }
            ]
        });

        const summary = completion.choices[0].message.content;
        const [keyPoints, nextSteps] = summary.split('\n\n');

        logger.info('Summary generated', { 
            transcriptLength: transcript.length
        });

        res.json({
            keyPoints: keyPoints.replace('Key Points:', '').trim(),
            nextSteps: nextSteps.replace('Next Steps:', '').trim()
        });
    } catch (error) {
        logger.error('Summarization error', { error: error.message });
        res.status(500).json({ error: 'Failed to summarize transcript' });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    logger.error('Server error', { error: err.message });
    res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    logger.info(`Server running on port ${PORT}`);
}); 