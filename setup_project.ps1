# Create directories
New-Item -ItemType Directory -Path 'dream_forum' | Out-Null
New-Item -ItemType Directory -Path 'dream_forum\app' | Out-Null
New-Item -ItemType Directory -Path 'dream_forum\app\templates' | Out-Null
New-Item -ItemType Directory -Path 'dream_forum\app\static' | Out-Null
New-Item -ItemType Directory -Path 'dream_forum\app\static\css' | Out-Null
New-Item -ItemType Directory -Path 'dream_forum\app\static\images' | Out-Null

# run.py
@"
from app import create_app

app = create_app()

if __name__ == "__main__":
    app.run(debug=True)
"@ | Out-File -Encoding UTF8 'dream_forum\run.py'

# __init__.py
@"
from flask import Flask
from .extensions import db
from .models import Board
import os

def create_app():
    app = Flask(__name__)
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(os.path.abspath(os.path.dirname(__file__)), '..', 'forum.db')
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SECRET_KEY'] = 'change_this_in_production'

    db.init_app(app)

    with app.app_context():
        from .routes import main_blueprint
        app.register_blueprint(main_blueprint)
        
        db.create_all()
        create_static_boards()

    return app


def create_static_boards():
    from .models import Board
    static_boards = [
        {
            'name': 'Dreams General',
            'description': 'A general board to tell about normal dreams.',
            'is_static': True,
        },
        {
            'name': 'Sleep Paralysis',
            'description': 'A board for sharing your sleep paralysis experiences.',
            'is_static': True,
        },
        {
            'name': 'Nightmares',
            'description': 'A board for sharing all types of nightmares.',
            'is_static': True,
        },
        {
            'name': 'Lucid Dreaming',
            'description': 'Share your lucid dreaming experiences and reality shifting techniques.',
            'is_static': True,
        },
        {
            'name': 'Trip Reports',
            'description': 'Share trip reports involving psychoactive substances.',
            'is_static': True,
        },
    ]
    for board_data in static_boards:
        board = Board.query.filter_by(name=board_data['name']).first()
        if not board:
            board = Board(**board_data)
            db.session.add(board)
    db.session.commit()
"@ | Out-File -Encoding UTF8 'dream_forum\app\__init__.py'

# extensions.py
@"
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
"@ | Out-File -Encoding UTF8 'dream_forum\app\extensions.py'

# models.py
@"
from .extensions import db
from datetime import datetime

class Board(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    description = db.Column(db.Text, nullable=False)
    is_static = db.Column(db.Boolean, default=False)

    def __repr__(self):
        return f"<Board {self.name}>"


class Thread(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    board_id = db.Column(db.Integer, db.ForeignKey('board.id'), nullable=False)
    board = db.relationship('Board', backref=db.backref('threads', lazy='dynamic'))
    title = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    created_by_ip = db.Column(db.String(45), nullable=False)

    def __repr__(self):
        return f"<Thread {self.title}>"


class Post(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    thread_id = db.Column(db.Integer, db.ForeignKey('thread.id'), nullable=False)
    thread = db.relationship('Thread', backref=db.backref('posts', lazy='dynamic', order_by="asc(Post.created_at)"))
    message = db.Column(db.Text, nullable=False)
    image = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    created_by_ip = db.Column(db.String(45), nullable=False)

    def __repr__(self):
        return f"<Post {self.id}>"
"@ | Out-File -Encoding UTF8 'dream_forum\app\models.py'

# forms.py
@"
from flask import request
from wtforms import Form, StringField, TextAreaField, FileField
from wtforms.validators import DataRequired, Length

class NewThreadForm(Form):
    title = StringField('Title', validators=[DataRequired(), Length(min=1, max=255)])
    message = TextAreaField('Message', validators=[DataRequired()])


class PostForm(Form):
    message = TextAreaField('Message', validators=[DataRequired()])
    image = FileField('Image (optional)')
"@ | Out-File -Encoding UTF8 'dream_forum\app\forms.py'

# routes.py
@"
import os
from flask import Blueprint, render_template, request, redirect, url_for
from .models import Board, Thread, Post
from .forms import NewThreadForm, PostForm
from .extensions import db
from werkzeug.utils import secure_filename

main_blueprint = Blueprint('main', __name__)

UPLOAD_FOLDER = 'app/static/images'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

def get_client_ip():
    x_forwarded_for = request.headers.get('X-Forwarded-For')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.remote_addr
    return ip

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@main_blueprint.route('/')
def index():
    boards = Board.query.all()
    return render_template('board_list.html', boards=boards)

@main_blueprint.route('/board/<int:board_id>')
def thread_list(board_id):
    board = Board.query.get_or_404(board_id)
    threads = board.threads.order_by(Thread.created_at.desc()).all()
    return render_template('threads.html', board=board, threads=threads)

@main_blueprint.route('/board/<int:board_id>/new_thread', methods=['GET','POST'])
def new_thread(board_id):
    board = Board.query.get_or_404(board_id)
    form = NewThreadForm(request.form)
    if request.method == 'POST' and form.validate():
        thread = Thread(
            board=board,
            title=form.title.data.strip(),
            created_by_ip=get_client_ip()
        )
        db.session.add(thread)
        db.session.commit()

        post = Post(
            thread=thread,
            message=form.message.data.strip(),
            created_by_ip=get_client_ip()
        )
        db.session.add(post)
        db.session.commit()

        return redirect(url_for('main.thread_posts', board_id=board.id, thread_id=thread.id))
    return render_template('new_thread.html', board=board, form=form)

@main_blueprint.route('/board/<int:board_id>/thread/<int:thread_id>')
def thread_posts(board_id, thread_id):
    thread = Thread.query.filter_by(id=thread_id, board_id=board_id).first_or_404()
    posts = thread.posts.all()
    return render_template('posts.html', thread=thread, posts=posts)

@main_blueprint.route('/board/<int:board_id>/thread/<int:thread_id>/reply', methods=['GET','POST'])
def reply_thread(board_id, thread_id):
    thread = Thread.query.filter_by(id=thread_id, board_id=board_id).first_or_404()
    form = PostForm(request.form)
    if request.method == 'POST' and form.validate():
        filename = None
        if 'image' in request.files:
            file = request.files['image']
            if file and allowed_file(file.filename):
                filename = secure_filename(file.filename)
                image_path = os.path.join(UPLOAD_FOLDER, filename)
                file.save(image_path)
                filename = filename

        post = Post(
            thread=thread,
            message=form.message.data.strip(),
            created_by_ip=get_client_ip(),
            image=filename
        )
        db.session.add(post)
        db.session.commit()
        return redirect(url_for('main.thread_posts', board_id=board_id, thread_id=thread_id))
    return render_template('reply_thread.html', thread=thread, form=form)
"@ | Out-File -Encoding UTF8 'dream_forum\app\routes.py'

# Templates

# base.html
@"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{% block title %}Dreams Archive{% endblock %}</title>
    <link href='https://fonts.googleapis.com/css2?family=Open+Sans&display=swap' rel='stylesheet'>
    <link rel='stylesheet' href='{{ url_for("static", filename="css/styles.css") }}'>
</head>
<body>
    <header>
        <h1><a href='{{ url_for("main.index") }}'>Dreams Archive</a></h1>
        <div class='what'>An anonymous forum for sharing dreams and hallucinations. No login required, but please follow the rules.</div>
    </header>
    <div class='content'>
        {% block content %}
        {% endblock %}
    </div>
</body>
</html>
"@ | Out-File -Encoding UTF8 'dream_forum\app\templates\base.html'

# board_list.html
@"
{% extends 'base.html' %}
{% block title %}Dreams Archive - Boards{% endblock %}
{% block content %}
<h2>Boards</h2>
<ul>
    {% for board in boards %}
    <li>
        <a href='{{ url_for("main.thread_list", board_id=board.id) }}'>{{ board.name }}</a><br>
        <small>{{ board.description }}</small>
    </li>
    {% endfor %}
</ul>
{% endblock %}
"@ | Out-File -Encoding UTF8 'dream_forum\app\templates\board_list.html'

# threads.html
@"
{% extends 'base.html' %}
{% block title %}{{ board.name }} - Threads{% endblock %}
{% block content %}
<h2>{{ board.name }}</h2>
<p>{{ board.description }}</p>
<a class='btn' href='{{ url_for("main.new_thread", board_id=board.id) }}'>Start New Thread</a>
<ul>
    {% for thread in threads %}
    <li>
        <a href='{{ url_for("main.thread_posts", board_id=board.id, thread_id=thread.id) }}'>{{ thread.title }}</a><br>
        <small>Started at {{ thread.created_at }} from {{ thread.created_by_ip }}</small>
    </li>
    {% endfor %}
    {% if threads|length == 0 %}
    <li>No threads yet.</li>
    {% endif %}
</ul>
{% endblock %}
"@ | Out-File -Encoding UTF8 'dream_forum\app\templates\threads.html'

# posts.html
@"
{% extends 'base.html' %}
{% block title %}{{ thread.title }} - Posts{% endblock %}
{% block content %}
<h2>{{ thread.title }}</h2>
<p><small>Board: <a href='{{ url_for("main.thread_list", board_id=thread.board.id) }}'>{{ thread.board.name }}</a></small></p>
<ul class='posts'>
    {% for post in posts %}
    <li class='post'>
        <div class='post-content'>
            {{ post.message|safe }}
            {% if post.image %}
            <div><img src='{{ url_for("static", filename="images/" ~ post.image) }}' alt='Attached image'></div>
            {% endif %}
        </div>
        <div class='post-meta'>
            Posted at {{ post.created_at }} from IP: {{ post.created_by_ip }}
        </div>
    </li>
    {% endfor %}
</ul>
<a class='btn' href='{{ url_for("main.reply_thread", board_id=thread.board.id, thread_id=thread.id) }}'>Reply</a>
{% endblock %}
"@ | Out-File -Encoding UTF8 'dream_forum\app\templates\posts.html'

# new_thread.html
@"
{% extends 'base.html' %}
{% block title %}New Thread in {{ board.name }}{% endblock %}
{% block content %}
<h2>New Thread in {{ board.name }}</h2>
<form method='post'>
    <input type='text' name='title' placeholder='Thread title' required>
    <textarea name='message' placeholder='Your message' required></textarea>
    <button type='submit'>Create Thread</button>
</form>
{% endblock %}
"@ | Out-File -Encoding UTF8 'dream_forum\app\templates\new_thread.html'

# reply_thread.html
@"
{% extends 'base.html' %}
{% block title %}Reply to {{ thread.title }}{% endblock %}
{% block content %}
<h2>Reply to: {{ thread.title }}</h2>
<form method='post' enctype='multipart/form-data'>
    <textarea name='message' placeholder='Your message' required></textarea>
    <input type='file' name='image' accept='image/*'>
    <button type='submit'>Post Reply</button>
</form>
{% endblock %}
"@ | Out-File -Encoding UTF8 'dream_forum\app\templates\reply_thread.html'

# styles.css
@"
body {
    background-color: #121212;
    color: #ffffff;
    font-family: 'Open Sans', sans-serif;
    margin: 0;
    padding: 0;
}

a {
    color: #9c63d3;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

header {
    background-color: #1f1f1f;
    padding: 20px;
    border-bottom: 1px solid #333;
}

header h1 {
    margin: 0;
}

header h1 a {
    color: #ffffff;
    text-decoration: none;
}

.content {
    padding: 20px;
}

ul {
    list-style-type: none;
    padding-left: 0;
}

li {
    margin-bottom: 15px;
}

form {
    max-width: 600px;
    margin: 0 auto;
}

form input, form textarea {
    width: 100%;
    padding: 10px;
    margin-bottom: 10px;
    background-color: #1f1f1f;
    color: #ffffff;
    border: 1px solid #333333;
    border-radius: 4px;
}

form button {
    padding: 10px 20px;
    background-color: #bb86fc;
    color: #ffffff;
    border: none;
    cursor: pointer;
    border-radius: 4px;
}

form button:hover {
    background-color: #9c63d3;
}

.btn {
    display: inline-block;
    padding: 10px 20px;
    background-color: #bb86fc;
    color: #ffffff;
    text-decoration: none;
    border-radius: 4px;
    margin-bottom: 20px;
}

.btn:hover {
    background-color: #9c63d3;
}

.posts {
    margin: 0;
    padding: 0;
}

.post {
    background-color: #1f1f1f;
    padding: 15px;
    margin-bottom: 10px;
    border-radius: 4px;
    border: 1px solid #333;
}

.post-content {
    margin-bottom: 10px;
    word-wrap: break-word;
}

.post-content img {
    max-width: 100%;
    height: auto;
    border-radius: 4px;
}

.post-meta {
    font-size: 0.9em;
    color: #a7a7a7;
}

.what {
    margin-top: 20px;
    padding-top: 20px;
    color: #bbbbbb;
    font-weight: 100;
}
"@ | Out-File -Encoding UTF8 'dream_forum\app\static\css\styles.css'

Write-Host "Project setup complete!"
