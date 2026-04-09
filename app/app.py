import os
import uuid
from flask import Flask, render_template, request, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
import boto3
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.secret_key = os.urandom(24)

DB_USER = os.getenv('DB_USER', 'dbadmin')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'testpass')
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_NAME = os.getenv('DB_NAME', 'projectdb')

app.config['SQLALCHEMY_DATABASE_URI'] = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

ATTACHMENTS_BUCKET = os.getenv('ATTACHMENTS_BUCKET', 'test-bucket')
AWS_REGION = os.getenv('AWS_REGION', 'ap-southeast-1')
s3_client = boto3.client('s3', region_name=AWS_REGION)

class Task(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=True)
    attachment_url = db.Column(db.String(500), nullable=True)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

with app.app_context():
    db.create_all()

@app.route('/')
def index():
    tasks = Task.query.order_by(Task.created_at.desc()).all()
    task_list = []
    for t in tasks:
        task_data = {
            'id': t.id,
            'title': t.title,
            'description': t.description,
            'created_at': t.created_at,
            'attachment_url': None,
            'attachment_key': None
        }
        if t.attachment_url:
            try:
                presigned_url = s3_client.generate_presigned_url('get_object',
                                                            Params={'Bucket': ATTACHMENTS_BUCKET,
                                                                    'Key': t.attachment_url},
                                                            ExpiresIn=3600)
                task_data['attachment_url'] = presigned_url
                task_data['attachment_key'] = t.attachment_url.split('/')[-1]
            except Exception as e:
                pass
        task_list.append(task_data)
        
    return render_template('index.html', tasks=task_list)

@app.route('/health')
def health():
    return {'status': 'ok'}, 200

@app.route('/create', methods=['GET', 'POST'])
def create_task():
    if request.method == 'POST':
        title = request.form['title']
        description = request.form['description']
        file = request.files.get('attachment')
        
        attachment_key = None
        if file and file.filename != '':
            ext = file.filename.split('.')[-1]
            attachment_key = f"tasks/{uuid.uuid4()}.{ext}"
            s3_client.upload_fileobj(file, ATTACHMENTS_BUCKET, attachment_key)

        new_task = Task(title=title, description=description, attachment_url=attachment_key)
        db.session.add(new_task)
        db.session.commit()
        return redirect(url_for('index'))
        
    return render_template('create.html')

@app.route('/delete/<int:task_id>', methods=['POST'])
def delete_task(task_id):
    task = Task.query.get_or_404(task_id)
    if task.attachment_url:
        try:
            s3_client.delete_object(Bucket=ATTACHMENTS_BUCKET, Key=task.attachment_url)
        except Exception:
            pass
    db.session.delete(task)
    db.session.commit()
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
