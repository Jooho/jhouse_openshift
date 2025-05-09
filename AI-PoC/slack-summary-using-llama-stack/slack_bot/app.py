import os
import logging
import requests
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from slack_bolt.adapter.flask import SlackRequestHandler
from flask import Flask, request, jsonify
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize logging with more detailed format
logging.basicConfig(
    level=logging.DEBUG, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"  # Change to DEBUG level
)
logger = logging.getLogger(__name__)

# Log environment variables (without sensitive values)
logger.info("Environment variables loaded:")
logger.info(f"SLACK_BOT_TOKEN exists: {bool(os.environ.get('SLACK_BOT_TOKEN'))}")
logger.info(f"SLACK_SIGNING_SECRET exists: {bool(os.environ.get('SLACK_SIGNING_SECRET'))}")

# Initialize Flask app
flask_app = Flask(__name__)

# Initialize the Slack app with signing secret
app = App(token=os.environ.get("SLACK_BOT_TOKEN"), signing_secret=os.environ.get("SLACK_SIGNING_SECRET"))

# Initialize the Slack request handler
handler = SlackRequestHandler(app)

# LLM Agent configuration
LLM_AGENT_URL = "http://localhost:8080/summarize"


def get_thread_messages(client, channel_id, thread_ts):
    """Get all messages in a thread, including sub-replies."""
    try:
        # Get the initial message
        result = client.conversations_replies(channel=channel_id, ts=thread_ts)

        messages = result["messages"]
        thread_data = []

        # Process each message in the thread
        for msg in messages:
            # Skip all bot messages
            if msg.get("bot_id"):
                continue

            # Skip "yes" responses
            if msg.get("text") == "yes":
                continue

            user_info = client.users_info(user=msg["user"])
            username = user_info["user"]["real_name"]

            message_data = {"user": username, "text": msg["text"], "ts": msg["ts"], "replies": []}

            # If this message has replies, process them
            if "thread_ts" in msg and msg["thread_ts"] != thread_ts:
                sub_replies = get_thread_messages(client, channel_id, msg["thread_ts"])
                message_data["replies"].extend(sub_replies)

            thread_data.append(message_data)

        return thread_data
    except Exception as e:
        logger.error(f"Error getting thread messages: {str(e)}")
        return []


def format_thread_data(thread_data, level=0):
    """Format thread data into a readable string."""
    formatted = ""
    indent = "  " * level

    for msg in thread_data:
        formatted += f"{indent}• {msg['user']}: {msg['text']}\n"
        if msg["replies"]:
            formatted += format_thread_data(msg["replies"], level + 1)

    return formatted


def prepare_data_for_ai(thread_data):
    """Prepare thread data for AI processing."""
    messages = []
    for msg in thread_data:
        messages.append({"text": msg["text"], "user": msg["user"], "timestamp": msg["ts"]})
        # Add replies if they exist
        if msg["replies"]:
            for reply in msg["replies"]:
                messages.append({"text": reply["text"], "user": reply["user"], "timestamp": reply["ts"]})
    return messages


class SummarizeHandler:
    def __init__(self, client, channel_id, thread_ts, user_id):
        self.client = client
        self.channel_id = channel_id
        self.thread_ts = thread_ts
        self.user_id = user_id
        self.state = "initial"  # Track the state of the summarize process

    def check_channel_access(self):
        """Check if the bot has access to the channel."""
        try:
            self.client.conversations_info(channel=self.channel_id)
            return True
        except Exception as e:
            self.client.chat_postMessage(
                channel=self.channel_id,
                text="I don't have access to this channel. Please make sure I'm invited and have the necessary permissions.",
                thread_ts=self.thread_ts,
            )
            return False

    def request_confirmation(self):
        """Request confirmation from the user."""
        self.client.chat_postMessage(
            channel=self.channel_id,
            text=f"<@{self.user_id}> Are you sure you want to summarize this thread? Reply with 'yes' to confirm.",
            thread_ts=self.thread_ts,
        )
        self.state = "waiting_confirmation"

    def process_thread(self):
        """Process the thread and generate summary."""
        try:
            # Get thread data
            thread_data = get_thread_messages(self.client, self.channel_id, self.thread_ts)
            logger.debug(f"Retrieved thread data: {thread_data}")

            if not thread_data:
                self.client.chat_postMessage(
                    channel=self.channel_id, text="No messages found in this thread.", thread_ts=self.thread_ts
                )
                return

            # Prepare data for AI processing
            messages = prepare_data_for_ai(thread_data)
            logger.debug(f"Prepared messages for LLM: {messages}")

            # Send request to LLM agent
            try:
                response = requests.post(LLM_AGENT_URL, json={"messages": messages}, timeout=30)
                response.raise_for_status()
                summary_data = response.json()

                if summary_data.get("status") == "success":
                    summary = summary_data.get("summary", "No summary generated")
                    self.client.chat_postMessage(
                        channel=self.channel_id,
                        text=f"Here's the AI summary of the thread:\n\n{summary}",
                        thread_ts=self.thread_ts,
                    )
                else:
                    error = summary_data.get("error", "Unknown error")
                    logger.error(f"Error from LLM agent: {error}")
                    self.client.chat_postMessage(
                        channel=self.channel_id,
                        text=f"Sorry, I couldn't generate a summary at this time. Error: {error}",
                        thread_ts=self.thread_ts,
                    )
            except requests.exceptions.RequestException as e:
                logger.error(f"Error calling LLM agent: {str(e)}")
                self.client.chat_postMessage(
                    channel=self.channel_id,
                    text="Sorry, I couldn't reach the summarization service. Please try again later.",
                    thread_ts=self.thread_ts,
                )

            self.state = "completed"
        except Exception as e:
            logger.error(f"Error processing thread: {str(e)}")
            self.client.chat_postMessage(
                channel=self.channel_id,
                text="An error occurred while processing the thread. Please try again later.",
                thread_ts=self.thread_ts,
            )
            self.state = "error"


@app.shortcut("loopy_thread")
def handle_summarize_shortcut(ack, shortcut, client):
    """Handle the summarize thread shortcut."""
    logger.debug(f"Received summarize shortcut: {shortcut}")
    ack()

    channel_id = shortcut["channel"]["id"]
    user_id = shortcut["user"]["id"]
    message_ts = shortcut["message_ts"]

    # Create handler instance
    handler = SummarizeHandler(client, channel_id, message_ts, user_id)

    # Request confirmation
    handler.request_confirmation()


@app.event("message")
def handle_message_events(body, logger):
    """Handle all message events."""
    event = body.get("event", {})
    logger.debug(f"Processing message event: {event}")

    # Only process messages that are "yes" responses
    if event.get("text") == "yes" and event.get("thread_ts"):
        logger.debug("Found 'yes' response in thread")
        try:
            # Get the client from the body's authorizations
            client = app.client
            channel_id = event["channel"]
            thread_ts = event["thread_ts"]
            user_id = event["user"]

            # Get thread messages
            result = client.conversations_replies(channel=channel_id, ts=thread_ts)
            logger.debug(f"Thread messages: {result}")

            if not result["messages"]:
                logger.error("No messages found in thread")
                return

            # Look for the most recent confirmation request message
            confirmation_message = None
            for msg in reversed(result["messages"]):
                if msg.get("bot_id") and "Are you sure you want to summarize this thread" in msg.get("text", ""):
                    confirmation_message = msg
                    break

            if not confirmation_message:
                logger.debug("No confirmation request message found")
                return

            logger.debug(f"Found confirmation request message: {confirmation_message}")

            # Get thread data
            thread_data = get_thread_messages(client, channel_id, thread_ts)
            logger.debug(f"Retrieved thread data: {thread_data}")

            if not thread_data:
                client.chat_postMessage(
                    channel=channel_id, text="No messages found in this thread.", thread_ts=thread_ts
                )
                return

            # Prepare data for AI processing
            messages = prepare_data_for_ai(thread_data)
            logger.debug(f"Prepared messages for LLM: {messages}")

            # Send request to LLM agent
            try:
                response = requests.post(LLM_AGENT_URL, json={"messages": messages}, timeout=30)
                response.raise_for_status()
                summary_data = response.json()

                if summary_data.get("status") == "success":
                    summary = summary_data.get("summary", "No summary generated")
                    client.chat_postMessage(
                        channel=channel_id,
                        text=f"Here's the AI summary of the thread:\n\n{summary}",
                        thread_ts=thread_ts,
                    )
                else:
                    error = summary_data.get("error", "Unknown error")
                    logger.error(f"Error from LLM agent: {error}")
                    client.chat_postMessage(
                        channel=channel_id,
                        text=f"Sorry, I couldn't generate a summary at this time. Error: {error}",
                        thread_ts=thread_ts,
                    )
            except requests.exceptions.RequestException as e:
                logger.error(f"Error calling LLM agent: {str(e)}")
                client.chat_postMessage(
                    channel=channel_id,
                    text="Sorry, I couldn't reach the summarization service. Please try again later.",
                    thread_ts=thread_ts,
                )

        except Exception as e:
            logger.error(f"Error processing message: {str(e)}")
            try:
                client.chat_postMessage(
                    channel=channel_id,
                    text="An error occurred while processing your confirmation. Please try again.",
                    thread_ts=thread_ts,
                )
            except Exception as e:
                logger.error(f"Error sending error message: {str(e)}")


@flask_app.route("/", methods=["POST"])
def slack_events_root():
    """Handle Slack events at root path."""
    logger.debug(f"Received request at root path: {request.headers}")
    return handler.handle(request)


@flask_app.route("/slack/events", methods=["POST"])
def slack_events():
    """Handle Slack events at /slack/events path."""
    logger.debug(f"Received request at /slack/events: {request.headers}")
    return handler.handle(request)


@flask_app.route("/", methods=["GET"])
def health_check():
    """Health check endpoint."""
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    # Run the Flask app on port 9999
    flask_app.run(port=9999, debug=True)
