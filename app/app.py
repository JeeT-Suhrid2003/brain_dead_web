import os

import psycopg
from flask import Flask, jsonify, request
from psycopg.rows import dict_row

app = Flask(__name__)


def connect():
    return psycopg.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ["DB_PORT"]),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        sslmode="verify-full",
        sslrootcert="/etc/pki/tls/certs/rds-global-bundle.pem",
        row_factory=dict_row,
    )

@app.get("/health")
def health():
    with connect() as connection:
        connection.execute("SELECT 1")
    return jsonify(status="ok")


@app.get("/records")
def list_records():
    with connect() as connection:
        records = connection.execute(
            "SELECT id, title, content, created_at FROM records ORDER BY id"
        ).fetchall()
    return jsonify(records)


@app.get("/records/<int:record_id>")
def get_record(record_id):
    with connect() as connection:
        record = connection.execute(
            """
            SELECT id, title, content, created_at
            FROM records
            WHERE id = %s
            """,
            (record_id,),
        ).fetchone()
    if record is None:
        return jsonify(error="Record not found"), 404
    return jsonify(record)


def parse_record():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return None

    title = payload.get("title")
    content = payload.get("content", "")
    if (
        not isinstance(title, str)
        or not title.strip()
        or len(title) > 200
        or not isinstance(content, str)
    ):
        return None
    return title.strip(), content


@app.post("/records")
def create_record():
    record = parse_record()
    if record is None:
        return (
            jsonify(error="Provide a non-empty title (max 200 characters) and string content"),
            400,
        )

    with connect() as connection:
        created = connection.execute(
            """
            INSERT INTO records (title, content)
            VALUES (%s, %s)
            RETURNING id, title, content, created_at
            """,
            record,
        ).fetchone()
    return jsonify(created), 201


@app.put("/records/<int:record_id>")
def update_record(record_id):
    record = parse_record()
    if record is None:
        return (
            jsonify(error="Provide a non-empty title (max 200 characters) and string content"),
            400,
        )

    with connect() as connection:
        updated = connection.execute(
            """
            UPDATE records
            SET title = %s, content = %s
            WHERE id = %s
            RETURNING id, title, content, created_at
            """,
            (*record, record_id),
        ).fetchone()
    if updated is None:
        return jsonify(error="Record not found"), 404
    return jsonify(updated)


@app.delete("/records/<int:record_id>")
def delete_record(record_id):
    with connect() as connection:
        deleted = connection.execute(
            "DELETE FROM records WHERE id = %s RETURNING id",
            (record_id,),
        ).fetchone()
    if deleted is None:
        return jsonify(error="Record not found"), 404
    return "", 204
