const fs = require('fs');
const path = require('path');
const express = require('express');
const nunjucks = require('nunjucks');
const multer = require('multer');
const { Sequelize, DataTypes } = require('sequelize');
const { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { v4: uuidv4 } = require('uuid');

// Load config
const configPath = path.join(__dirname, 'app_config.json');
if (fs.existsSync(configPath)) {
    const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
    for (const [key, value] of Object.entries(config)) {
        if (value !== null) {
            process.env[String(key)] = String(value);
        }
    }
} else {
    require('dotenv').config();
}

const app = express();
app.use(express.urlencoded({ extended: true }));
app.use('/static', express.static(path.join(__dirname, 'static')));

// Configure Nunjucks
nunjucks.configure('templates', {
    autoescape: true,
    express: app
});
app.set('view engine', 'html');

// Create Flash logic middleware (Express doesn't have it built-in)
app.use(require('express-session')({ secret: process.env.SECRET_KEY || 'dev-secret-key', resave: false, saveUninitialized: false }));
const flash = require('connect-flash');
app.use(flash());
app.use((req, res, next) => {
    res.locals.get_flashed_messages = () => {
        const msgs = req.flash();
        return Object.values(msgs).flat();
    };
    next();
});

// Database Setup
const DB_USER = process.env.DB_USER || 'dbadmin';
const DB_PASSWORD = process.env.DB_PASSWORD || 'testpass';
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_NAME = process.env.DB_NAME || 'projectdb';
const DB_SSLMODE = process.env.DB_SSLMODE || 'prefer';

const dialectOptions = DB_SSLMODE === 'require' ? { ssl: { require: true, rejectUnauthorized: false } } : {};

const sequelize = new Sequelize(DB_NAME, DB_USER, DB_PASSWORD, {
    host: DB_HOST,
    dialect: 'postgres',
    dialectOptions: dialectOptions,
    logging: false,
    pool: {
        max: 5,
        min: 0,
        acquire: 15000,
        idle: 10000
    }
});

const Task = sequelize.define('Task', {
    title: {
        type: DataTypes.STRING(100),
        allowNull: false
    },
    description: {
        type: DataTypes.TEXT,
        allowNull: true
    },
    attachment_url: {
        type: DataTypes.STRING(500),
        allowNull: true
    },
    created_at: {
        type: DataTypes.DATE,
        defaultValue: Sequelize.NOW
    }
}, {
    timestamps: false,
    tableName: 'task'
});

// S3 configure
const ATTACHMENTS_BUCKET = process.env.ATTACHMENTS_BUCKET || 'test-bucket';
const AWS_REGION = process.env.AWS_REGION || 'ap-southeast-1';
const s3Client = new S3Client({ region: AWS_REGION });

// Multer setup for memory storage (we'll stream to S3)
const upload = multer({ storage: multer.memoryStorage() });

// Routes
app.get('/', async (req, res) => {
    try {
        const tasks = await Task.findAll({ order: [['created_at', 'DESC']] });
        const taskList = [];

        for (const t of tasks) {
            const taskData = {
                id: t.id,
                title: t.title,
                description: t.description,
                created_at: t.created_at,
                attachment_url: null,
                attachment_key: null
            };

            if (t.attachment_url) {
                try {
                    const command = new GetObjectCommand({
                        Bucket: ATTACHMENTS_BUCKET,
                        Key: t.attachment_url
                    });
                    const presignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
                    taskData.attachment_url = presignedUrl;
                    taskData.attachment_key = t.attachment_url.split('/').pop();
                } catch (e) {
                    console.error("Presigned URL error:", e);
                }
            }
            taskList.push(taskData);
        }

        res.render('index', { tasks: taskList });
    } catch (err) {
        console.error(err);
        res.status(500).send("Internal Server Error");
    }
});

app.get('/health', (req, res) => {
    res.status(200).type('text/plain').send('ok');
});

app.get('/create', (req, res) => {
    res.render('create');
});

app.post('/create', upload.single('attachment'), async (req, res) => {
    try {
        const title = req.body.title;
        const description = req.body.description;
        const file = req.file;

        let attachment_key = null;
        if (file) {
            const ext = file.originalname.split('.').pop();
            attachment_key = `tasks/${uuidv4()}.${ext}`;
            
            const command = new PutObjectCommand({
                Bucket: ATTACHMENTS_BUCKET,
                Key: attachment_key,
                Body: file.buffer,
                ContentType: file.mimetype
            });
            await s3Client.send(command);
        }

        await Task.create({
            title: title,
            description: description,
            attachment_url: attachment_key
        });

        res.redirect('/');
    } catch (err) {
        console.error(err);
        res.status(500).send("Error creating task");
    }
});

app.post('/delete/:taskId', async (req, res) => {
    try {
        const task = await Task.findByPk(req.params.taskId);
        if (!task) return res.status(404).send('Not Found');

        if (task.attachment_url) {
            try {
                const command = new DeleteObjectCommand({
                    Bucket: ATTACHMENTS_BUCKET,
                    Key: task.attachment_url
                });
                await s3Client.send(command);
            } catch (e) {
                console.error("Delete object error", e);
            }
        }

        await task.destroy();
        res.redirect('/');
    } catch (err) {
        console.error(err);
        res.status(500).send("Error deleting task");
    }
});

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server listening on port ${PORT}`);
});

module.exports = { sequelize, Task };
