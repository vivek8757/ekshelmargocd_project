const express = require('express');
const mongoose = require('mongoose');
const multer = require('multer');
const cors = require('cors');
const { S3Client, PutObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Enable CORS & JSON parsing
app.use(cors());
app.use(express.json());

// MongoDB Connection
const mongoURI = process.env.MONGODB_URI;
if (!mongoURI) {
  console.warn("WARNING: MONGODB_URI is not defined. MongoDB integration will be disabled.");
} else {
  mongoose.connect(mongoURI)
    .then(() => console.log('Successfully connected to MongoDB Atlas.'))
    .catch(err => console.error('MongoDB Atlas connection error:', err));
}

// Name Schema & Model
const NameSchema = new mongoose.Schema({
  name: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});
const NameModel = mongoose.model('Name', NameSchema);

// File Metadata Schema & Model
const FileMetadataSchema = new mongoose.Schema({
  originalName: { type: String, required: true },
  s3Key: { type: String, required: true },
  s3Url: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});
const FileMetadataModel = mongoose.model('FileMetadata', FileMetadataSchema);

// AWS S3 Configuration
const s3BucketName = process.env.S3_BUCKET_NAME;
const awsRegion = process.env.AWS_REGION || 'us-east-1';

if (!s3BucketName) {
  console.warn("WARNING: S3_BUCKET_NAME is not defined. S3 upload will fail if invoked.");
}

// S3 Client automatically resolves credentials via EKS IRSA (IAM Roles for Service Accounts)
// or standard AWS environment variables if running locally.
const s3Client = new S3Client({ region: awsRegion });

// Setup Multer for memory storage
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

// --- API ROUTES ---

// Health Check Endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    mongodb: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    s3Bucket: s3BucketName ? 'configured' : 'not_configured',
    timestamp: new Date()
  });
});

// API 1: Store Name in MongoDB Atlas
app.post('/api/names', async (req, res) => {
  const { name } = req.body;
  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Name is required' });
  }

  try {
    const newName = new NameModel({ name });
    await newName.save();
    res.status(201).json({ message: 'Name stored successfully', data: newName });
  } catch (error) {
    console.error('Error saving name to MongoDB:', error);
    res.status(500).json({ error: 'Failed to save name to database' });
  }
});

// API 1 helper: Get all Names
app.get('/api/names', async (req, res) => {
  try {
    const names = await NameModel.find().sort({ createdAt: -1 });
    res.json(names);
  } catch (error) {
    console.error('Error fetching names:', error);
    res.status(500).json({ error: 'Failed to fetch names' });
  }
});

// API 2: Upload file and store in S3 bucket, saving metadata in MongoDB
app.post('/api/files', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  if (!s3BucketName) {
    return res.status(500).json({ error: 'S3 bucket is not configured on the server' });
  }

  const file = req.file;
  // Generate unique file name to prevent collision in S3
  const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
  const s3Key = `uploads/${uniqueSuffix}-${path.basename(file.originalname)}`;

  try {
    // Upload buffer directly to S3
    const uploadParams = {
      Bucket: s3BucketName,
      Key: s3Key,
      Body: file.buffer,
      ContentType: file.mimetype
    };

    await s3Client.send(new PutObjectCommand(uploadParams));
    
    // Construct S3 URL (using virtual-hosted-style URL)
    const s3Url = `https://${s3BucketName}.s3.${awsRegion}.amazonaws.com/${s3Key}`;

    // Store metadata in MongoDB (if connected)
    let savedMetadata = null;
    if (mongoose.connection.readyState === 1) {
      const metadata = new FileMetadataModel({
        originalName: file.originalname,
        s3Key: s3Key,
        s3Url: s3Url
      });
      savedMetadata = await metadata.save();
    }

    res.status(201).json({
      message: 'File uploaded to S3 successfully',
      fileName: file.originalname,
      s3Key: s3Key,
      s3Url: s3Url,
      dbRecord: savedMetadata
    });
  } catch (error) {
    console.error('Error uploading file to S3 or saving metadata:', error);
    res.status(500).json({ error: 'Failed to upload file to S3', details: error.message });
  }
});

// API 2 helper: Get all uploaded files metadata
app.get('/api/files', async (req, res) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      return res.status(503).json({ error: 'Database not connected' });
    }
    const files = await FileMetadataModel.find().sort({ createdAt: -1 });
    res.json(files);
  } catch (error) {
    console.error('Error fetching files metadata:', error);
    res.status(500).json({ error: 'Failed to fetch files metadata' });
  }
});

// Start Server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
