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
    # Removed the upvotes column

    def __repr__(self):
        return f"<Post {self.id}>"

class UserVisit(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    ip = db.Column(db.String(45), unique=True, nullable=False)

    def __repr__(self):
        return f"<UserVisit {self.ip}>"
