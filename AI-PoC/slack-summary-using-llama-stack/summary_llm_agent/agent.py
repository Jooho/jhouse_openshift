import os
from typing import List, Dict
import requests
from flask import Flask, request, jsonify
from dotenv import load_dotenv
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = Flask(__name__)

LLAMASTACK_URL = "http://localhost:8321/v1/inference/chat-completion"
MODEL_NAME = "meta-llama/Llama-3.2-1B-Instruct"


def format_messages_for_llm(messages: List[Dict]) -> str:
    """Format messages into a prompt for the LLM."""
    formatted_text = "Please summarize the following conversation thread:\n\n"
    for msg in messages:
        formatted_text += f"{msg['user']} ({msg['timestamp']}): {msg['text']}\n"
    return formatted_text


def get_llm_summary(messages: List[Dict]) -> str:
    """Get summary from LlamaStack."""
    prompt = format_messages_for_llm(messages)

    try:
        logger.info(f"Sending request to LlamaStack with model: {MODEL_NAME}")
        response = requests.post(
            LLAMASTACK_URL,
            json={
                "model_id": MODEL_NAME,
                "messages": [
                    {
                        "role": "system",
                        "content": "You are a helpful assistant that summarizes conversation threads. Provide concise and clear summaries.",
                    },
                    {"role": "user", "content": prompt},
                ],
                "temperature": 0.7,
                "max_tokens": 500,
            },
            timeout=30,
        )
        response.raise_for_status()
        logger.info(f"LlamaStack Response: {response.text}")
        return response.json().get("completion_message", {}).get("content", "Error: No response text")
    except requests.exceptions.RequestException as e:
        logger.error(f"Error calling LlamaStack: {str(e)}")
        return f"Error calling LlamaStack: {str(e)}"
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return f"Unexpected error: {str(e)}"


@app.route("/summarize", methods=["POST"])
def summarize_thread():
    """Endpoint to summarize a thread of messages."""
    try:
        data = request.get_json()
        if not data or "messages" not in data:
            return jsonify({"error": "Invalid request: 'messages' field is required", "status": "error"}), 400

        messages = data.get("messages", [])
        if not messages:
            return jsonify({"error": "No messages provided", "status": "error"}), 400

        summary = get_llm_summary(messages)
        return jsonify({"summary": summary, "status": "success"})
    except Exception as e:
        logger.error(f"Error in summarize_thread: {str(e)}")
        return jsonify({"error": str(e), "status": "error"}), 500


if __name__ == "__main__":
    logger.info(f"Starting agent with model: {MODEL_NAME}")
    app.run(host="0.0.0.0", port=8080, debug=False)  # Disabled debug mode
