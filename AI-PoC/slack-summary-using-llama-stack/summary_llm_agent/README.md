# Thread Summary LLM Agent

This is a FastAPI-based LLM agent that summarizes Slack thread conversations using LlamaStack and Ollama.

## Prerequisites

- Python 3.8+
- LlamaStack running on localhost:8321
- Ollama running with Llama2 model

## Setup

1. Create a virtual environment:

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:

```bash
pip3 install -r requirements.txt
```

## Running the Agent

Start the agent server:

```bash
python agent.py
```

The server will start on `http://localhost:8000`.

## API Endpoints

### POST /summarize

Summarizes a thread of Slack messages.

Request body:

```json
{
  "messages": [
    {
      "text": "Message content",
      "user": "User ID",
      "timestamp": "Message timestamp"
    }
  ],
  "channel_id": "Channel ID",
  "thread_ts": "Thread timestamp"
}
```

Response:

```json
{
  "summary": "Generated summary of the thread",
  "status": "success"
}
```

## Integration with Slack Bot

The Slack bot should send thread messages to this agent's `/summarize` endpoint. The agent will process the messages through LlamaStack and return a summary that can be posted back to Slack.
