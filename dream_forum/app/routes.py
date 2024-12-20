import os
import requests
from flask import Blueprint, render_template, request, redirect, url_for, abort
from .models import Board, Thread, Post, UserVisit
from .forms import NewThreadForm, PostForm
from .extensions import db
from werkzeug.utils import secure_filename

main_blueprint = Blueprint('main', __name__)

UPLOAD_FOLDER = 'app/static/images'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

ADMIN_PASSWORD = "ChangeThisPassword"

RECAPTCHA_SITE_KEY = "6Lfy6pgqAAAAAA3biflBFAU7Yez3b0pC_DFQ79sF"
RECAPTCHA_SECRET_KEY = "6Lfy6pgqAAAAAM7zVHRLOV56ubRolGqw6LHWSHyA"

def get_client_ip():
    x_forwarded_for = request.headers.get('X-Forwarded-For')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.remote_addr
    return ip

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def ensure_user_count(ip):
    if not UserVisit.query.filter_by(ip=ip).first():
        uv = UserVisit(ip=ip)
        db.session.add(uv)
        db.session.commit()

def verify_captcha(response):
    if not response:
        return False
    payload = {
        'secret': RECAPTCHA_SECRET_KEY,
        'response': response
    }
    r = requests.post('https://www.google.com/recaptcha/api/siteverify', data=payload)
    result = r.json()
    return result.get('success', False)

@main_blueprint.route('/')
def index():
    boards = Board.query.all()
    user_count = UserVisit.query.count()
    return render_template('board_list.html', boards=boards, user_count=user_count)

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
        captcha_response = request.form.get('g-recaptcha-response')
        if not verify_captcha(captcha_response):
            return ("Captcha failed, please try again"), 400

        thread = Thread(
            board=board,
            title=form.title.data.strip(),
            created_by_ip=get_client_ip()
        )
        db.session.add(thread)
        db.session.commit()

        # Create initial post
        post = Post(
            thread=thread,
            message=form.message.data.strip(),
            created_by_ip=get_client_ip()
        )
        db.session.add(post)
        db.session.commit()

        ensure_user_count(get_client_ip())

        return redirect(url_for('main.thread_posts', board_id=board.id, thread_id=thread.id))
    return render_template('new_thread.html', board=board, form=form, recaptcha_site_key=RECAPTCHA_SITE_KEY)

@main_blueprint.route('/board/<int:board_id>/thread/<int:thread_id>')
def thread_posts(board_id, thread_id):
    thread = Thread.query.filter_by(id=thread_id, board_id=board_id).first_or_404()
    posts = thread.posts.all()
    return render_template('posts.html', thread=thread, posts=posts, recaptcha_site_key=RECAPTCHA_SITE_KEY)

@main_blueprint.route('/board/<int:board_id>/thread/<int:thread_id>/reply', methods=['GET','POST'])
def reply_thread(board_id, thread_id):
    thread = Thread.query.filter_by(id=thread_id, board_id=board_id).first_or_404()
    form = PostForm(request.form)
    if request.method == 'POST' and form.validate():
        captcha_response = request.form.get('g-recaptcha-response')
        if not verify_captcha(captcha_response):
            return "Captcha failed. Please try again.", 400

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

        ensure_user_count(get_client_ip())

        return redirect(url_for('main.thread_posts', board_id=board_id, thread_id=thread_id))
    return render_template('reply_thread.html', thread=thread, form=form, recaptcha_site_key=RECAPTCHA_SITE_KEY)

@main_blueprint.route('/delete_post/<int:post_id>', methods=['POST'])
def delete_post(post_id):
    password = request.form.get('admin_password')
    if password != ADMIN_PASSWORD:
        abort(403, "Unauthorized")

    post = Post.query.get_or_404(post_id)
    db.session.delete(post)
    db.session.commit()
    return redirect(request.referrer or url_for('main.index'))

@main_blueprint.route('/rules')
def rules():
    return render_template('rules.html')
