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
