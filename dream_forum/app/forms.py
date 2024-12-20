from flask import request
from wtforms import Form, StringField, TextAreaField, FileField
from wtforms.validators import DataRequired, Length

class NewThreadForm(Form):
    title = StringField('Title', validators=[DataRequired(), Length(min=1, max=255)])
    message = TextAreaField('Message', validators=[DataRequired()])


class PostForm(Form):
    message = TextAreaField('Message', validators=[DataRequired()])
    image = FileField('Image (optional)')
