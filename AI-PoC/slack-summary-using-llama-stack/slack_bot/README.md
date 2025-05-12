# Slack Thread Summarizer Bot

This Slack bot collects and summarizes thread data, with future AI-powered summarization capabilities.

## Setup Instructions

1. Create a new Slack App at https://api.slack.com/apps
2. Enable the following Bot Token Scopes under "OAuth & Permissions":

   - `channels:history`
   - `groups:history`
   - `im:history`
   - `mpim:history`
   - `chat:write`
   - `reactions:read`
   - `users:read`
   - `commands` (for /summarize command)

3. Install the app to your workspace
4. Create a `.env` file with the following variables:

   ```
   SLACK_BOT_TOKEN=xoxb-your-bot-token
   SLACK_APP_TOKEN=xapp-your-app-token
   SLACK_SIGNING_SECRET=your-signing-secret  # Get this from Basic Information > App Credentials

   #cp ~/temp/test-debug/TOKEN/SLACK_TOKEN .env
   ```

5. Install dependencies:

   ```bash
   python -m venv venv
   source venv/bin/activate
   ./venv/bin/pip3 install -r requirements.txt
   ```

6. For local development, install ngrok:

   ```bash
   # On Linux/macOS
   curl https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar xvz

   # On Windows, download from https://ngrok.com/download
   ```

7. Start ngrok to create a secure tunnel:

   ```bash
   ngrok http --url https://YOUR_NGROK http://localhost:9999
   #ngrok http --url https://internal-similarly-cockatoo.ngrok-free.app http://localhost:9999
   ```

8. Update your Slack App settings:

   - Go to your Slack App settings
   - Under "Event Subscriptions", enable it
   - Set the Request URL to your ngrok URL
     (e.g., https://your-ngrok-url.ngrok.io)
   - Add the events under Subscribe to bot events  
     ![bot-events](bot-events.png)
   - Under "Basic Information", copy the "Signing Secret" to your .env file
   - create app_level token under "Basic Information"
      ![app-level-token](app-level-token.png)
   
9. Run the bot:

   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate 
   python run.py
   ```

## Usage

1. Invite the bot to your channel
2. To summarize a thread:
   - Type `/summarize` in the thread you want to summarize
   - The bot will ask for confirmation
   - Reply with "yes" to confirm
   - The bot will collect and display the thread data
   - (Coming soon) AI-powered summary of the thread

## Features

- Collects all messages in a specific thread, including sub-replies
- Triggered by `/summarize` command in the target thread
- Confirms before collecting data
- Formats the collected data in a readable format
- Handles nested thread replies
- (Coming soon) AI-powered thread summarization

## Development Notes

- The bot runs on port 9999 by default
- Uses Gunicorn as the WSGI server
- Configured with 4 worker processes
- 30-second timeout for requests
- Bind to all interfaces (0.0.0.0) for external access
