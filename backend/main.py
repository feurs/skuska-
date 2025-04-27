from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os, psycopg

app = FastAPI(title="TODO API")

DB_URL = os.getenv("DATABASE_URL")
conn = psycopg.connect(DB_URL, autocommit=True)
with conn.cursor() as cur:
    cur.execute("""
        CREATE TABLE IF NOT EXISTS todo (
          id   SERIAL PRIMARY KEY,
          text TEXT   NOT NULL
        );
    """)

class TodoIn(BaseModel):
    text: str

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/todos")
async def add_todo(item: TodoIn):
    with conn.cursor() as cur:
        cur.execute("INSERT INTO todo(text) VALUES (%s) returning id", (item.text,))
        todo_id = cur.fetchone()[0]
    return {"id": todo_id, **item.dict()}

@app.get("/todos")
async def list_todos():
    with conn.cursor() as cur:
        cur.execute("SELECT id,text FROM todo ORDER BY id")
        rows = cur.fetchall()
    return [{"id": i, "text": t} for i, t in rows]

